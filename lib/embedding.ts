import type { BaseNodePostprocessor, BaseRetriever, BaseSynthesizer, Metadata, MetadataFilter, MetadataFilters, ModalityType, QueryEngineToolParams, VectorIndexChatEngineOptions, VectorIndexRetrieverOptions } from 'llamaindex';

import type { FileMetadata, OmitFrom, StorageLocation } from '@freehour/supabase-core';


/**
 * The type of metadata that will be stored with each embedded document.
 */
export type DocumentMetadata = StorageLocation & FileMetadata & Metadata;

export type RetriverOptions = OmitFrom<VectorIndexRetrieverOptions, 'index' | 'filters'> & {
    /**
     * Filters to apply to the documents before retrieval.
     * Only documents that match the filters will be included in the result.
     */
    filters?: Partial<DocumentMetadata>;
} & ({
    topK?: Record<ModalityType, number>;
} | {
    similarityTopK?: number;
});

export interface QueryEngineOptions {
    retriever?: BaseRetriever;
    responseSynthesizer?: BaseSynthesizer;

    /**
     * Filters to apply to the documents before querying.
     * Only documents that match the filters will be included in the query.
     */
    filters?: Partial<DocumentMetadata>;
    customParams?: unknown;
    nodePostprocessors?: BaseNodePostprocessor[];
    similarityTopK?: number;
}


export interface QueryToolOptions extends QueryEngineOptions, OmitFrom<QueryEngineToolParams, 'queryEngine'> {
}

export interface ChatEngineOptions extends OmitFrom<VectorIndexChatEngineOptions, 'preFilters'> {
    /**
     * Filters to apply to the documents before querying.
     * Only documents that match the filters will be included in the query.
     */
    filters?: Partial<DocumentMetadata>;
}

export function toMetadataFilters(filter: Partial<DocumentMetadata>): MetadataFilters {
    return {
        filters: Object.entries(filter)
            .filter(([, value]) => value !== undefined)
            .map(([key, value]): MetadataFilter => ({
                key,
                value,
                operator: '==',
            })),
        condition: 'and',
    };
}
