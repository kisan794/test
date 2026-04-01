sources.forEach(source -> {
                    String indexName = Helper.getIndexName(source.getOrganizationType().getType());
                    sourcesByIndex.computeIfAbsent(indexName, k -> new ArrayList<>()).add(source);
                });



 // Bulk update Elasticsearch by index
    sourcesByIndex.forEach((indexName, sources) -> {
        try {
            elasticsearchService.bulkUpdateAutomatedService(indexName, sources);
        } catch (IOException e) {
            log.error("Bulk ES update failed for index: {}", indexName, e);
        }
    });


public void bulkUpdateAutomatedService(String indexName, List<Source> sources) throws IOException {
    BulkRequest.Builder bulkBuilder = new BulkRequest.Builder();
    
    for (Source source : sources) {
        ElasticsearchSource searchSource = elasticsearchMapper.sourceToSearchSourceMapping(source);
        
        if (searchSource != null) {
            Map<String, Object> updateFields = new HashMap<>();
            updateFields.put("automatedService", searchSource.getAutomatedService());
            updateFields.put("code", searchSource.getCode());
            
            bulkBuilder.operations(op -> op
                .update(u -> u
                    .index(indexName)
                    .id(source.getHon())
                    .action(a -> a.doc(updateFields))
                )
            );
        }
    }
    
    BulkResponse result = elasticsearchClient.bulk(bulkBuilder.build());
    log.info("Bulk ES update completed for index: {} - items: {}, errors: {}", 
        indexName, result.items().size(), result.errors());
}
