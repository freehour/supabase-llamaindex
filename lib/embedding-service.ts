
import type { BaseChatEngine, BaseQueryEngine, BaseRetriever, BaseVectorStore } from 'llamaindex';
import { Document, QueryEngineTool, storageContextFromDefaults, VectorStoreIndex } from 'llamaindex';

import type { ClientServerOptions, ColumnName, DefaultClientOptions, Embedding, EmbeddingServiceParams, FileMetadata, GenericDatabase, Metadata, SchemaName, StorageLocation } from '@freehour/supabase-core';
import { DatabaseService, EmbeddingService } from '@freehour/supabase-core';
import { SupabaseVectorStore } from '@llamaindex/supabase';
import type { SupabaseClient } from '@supabase/supabase-js';

import type { Database as LlamaindexDatabase } from './generated/database';
import type { ChatEngineOptions, QueryEngineOptions, QueryToolOptions, RetriverOptions } from './embedding';
import { toMetadataFilters } from './embedding';


export interface LlamaindexEmbeddingServiceParams<
    Database extends GenericDatabase<SchemaName<Database>> & LlamaindexDatabase = LlamaindexDatabase,
    ClientOptions extends Required<ClientServerOptions> = DefaultClientOptions<Database>,
    BucketName extends string = string,
> extends EmbeddingServiceParams<BucketName> {
    supabase: SupabaseClient<Database, ClientOptions>;
}

export class LlamaindexEmbeddingService<
    Database extends GenericDatabase<SchemaName<Database>> & LlamaindexDatabase = LlamaindexDatabase,
    ClientOptions extends Required<ClientServerOptions> = DefaultClientOptions<Database>,
    BucketName extends string = string,
> extends EmbeddingService<BucketName> {

    private readonly database: DatabaseService<LlamaindexDatabase>;
    private readonly vectorStore: BaseVectorStore;


    constructor({
        supabase,
        ...params
    }: LlamaindexEmbeddingServiceParams<Database, ClientOptions, BucketName>) {
        super(params);
        this.database = new DatabaseService({ supabase }) as unknown as DatabaseService<LlamaindexDatabase>;
        this.vectorStore = new SupabaseVectorStore({
            client: supabase as SupabaseClient,
            table: this.embeddings.relation,
        });
    }

    private get embeddings() {
        return this.database.table('public', 'embeddings');
    }

    protected override async getEmbeddings(location: StorageLocation): Promise<Embedding[]> {
        const { fileId } = location;
        const { data } = await this.embeddings.query
            .select(['content', 'embedding', 'metadata', 'created_at'])
            .eq<ColumnName<LlamaindexDatabase, 'public', 'Tables', 'embeddings'>>('file_id', fileId)
            .throwOnError();

        return data.map(({
            content,
            embedding,
            metadata,
            created_at,
        }): Embedding => ({
            ...location,
            text: content,
            vector: embedding !== null ? JSON.parse(embedding) : null,
            metadata: metadata as FileMetadata & Metadata,
            createdAt: new Date(created_at),
        }));

    }

    protected override async createEmbeddings(location: StorageLocation, text: string, file: FileMetadata, metadata: Metadata): Promise<Embedding[]> {
        // create a document and ingest it into the vector store
        const document = new Document<FileMetadata & Metadata & StorageLocation>({
            text,
            metadata: {
                ...file,
                ...metadata,
                ...location,
            },
        });

        // the storage context is used to save the embedding in the vector store and consequently in the embeddings table
        const storageContext = await storageContextFromDefaults({ vectorStore: this.vectorStore });
        await VectorStoreIndex.fromDocuments([document], {
            storageContext,
        });

        return this.getEmbeddings(location);
    }

    protected override async deleteEmbeddings({ fileId }: StorageLocation): Promise<void> {
        await this.embeddings.query
            .delete()
            .eq<ColumnName<LlamaindexDatabase, 'public', 'Tables', 'embeddings'>>('file_id', fileId)
            .throwOnError();
    }

    async getIndex(): Promise<VectorStoreIndex> {
        return VectorStoreIndex.fromVectorStore(this.vectorStore);
    }

    /**
     * Create a retriever that can be used to retrieve documents using similarity search.
     * @returns The retriever.
     */
    async getRetriever({
        filters,
        ...options
    }: RetriverOptions = {}): Promise<BaseRetriever> {
        return this.getIndex().then(index => index.asRetriever({
            filters: filters ? toMetadataFilters(filters) : undefined,
            ...options,
        }));
    }

    /**
     * Create a query engine that can be used to query documents using natural language queries.
     * @returns The query engine.
     */
    async getQueryEngine({
        filters,
        ...options
    }: QueryEngineOptions = {}): Promise<BaseQueryEngine> {
        return this.getIndex().then(index => index.asQueryEngine({
            preFilters: filters ? toMetadataFilters(filters) : undefined,
            ...options,
        }));
    }

    /**
     * Create a query tool that can be used by agents to query documents.
     * @returns The query tool.
     */
    async getQueryTool({
        includeSourceNodes,
        metadata,
        ...options
    }: QueryToolOptions = {}): Promise<QueryEngineTool> {
        const queryEngine = await this.getQueryEngine(options);
        return new QueryEngineTool({
            queryEngine,
            metadata,
            includeSourceNodes,
        });
    }

    /**
     * Create a chat engine that can be used to chat about the documents.
     * @returns The chat engine.
     */
    async getChatEngine({
        filters,
        ...options
    }: ChatEngineOptions = {}): Promise<BaseChatEngine> {
        return this.getIndex().then(index => index.asChatEngine({
            preFilters: filters ? toMetadataFilters(filters) : undefined,
            ...options,
        }));
    }
}
