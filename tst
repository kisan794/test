 // Add facet and projection to wrap results
        FacetOperation actionFacet = Aggregation.facet()
                .and(Aggregation.count().as("count")).as("total")
                .and(actionGroup).as("data");
        ProjectionOperation actionProjection = Aggregation.project()
                .and(ArrayOperators.ArrayElemAt.arrayOf("total.count").elementAt(0)).as("total")
                .and("data").as("operatorReviewerReportList");

        AggregationOptions aggregationOptions = AggregationOptions.builder()
                .allowDiskUse(true).build();

        Aggregation actionAggregation = Aggregation.newAggregation(actionMatch, actionFacet, actionProjection)
                .withOptions(aggregationOptions);
