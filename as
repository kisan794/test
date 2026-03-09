package com.hireright.sourceintelligence.util;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.databind.node.MissingNode;
import com.fasterxml.jackson.databind.node.NullNode;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import java.util.*;

public class DeepDiffUtil {


    private DeepDiffUtil() {

    }

    private static final ObjectMapper MAPPER = new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);


    // Configure these as needed
    private static final Set<String> SKIP_FIELDS = Set.of("id","searchOrg","createdDate", "lastModifiedDate", "createdBy",
            "creatorId", "action", "tempVersion", "version", "logFlag", "approvalStatus", "status","approvedBy","approverId","lastModifierId","lastModifiedBy",
            "assignedTo", "assignedId", "payload.usedCount", "payload.lastUsedDateTime","isLockEnabled","location","comments","generalErrors","fieldErrors");

    public static List<String> findChangedFields(Object obj1, Object obj2) {
        JsonNode left = obj1 == null ? NullNode.getInstance() : MAPPER.valueToTree(obj1);
        JsonNode right = obj2 == null ? NullNode.getInstance() : MAPPER.valueToTree(obj2);

        List<String> changes = new ArrayList<>();
        diffNodes(left, right, "", changes);
        return changes;
    }
    private static void diffNodes(JsonNode left, JsonNode right, String path, List<String> changes) {


// Normalize nulls to MissingNode to simplify checks
        if (left == null) left = MissingNode.getInstance();
        if (right == null) right = MissingNode.getInstance();

// === SPECIAL RULE: empty array == missing field ===
        boolean leftEmptyArray = left.isArray() && left.isEmpty();
        boolean rightEmptyArray = right.isArray() && right.isEmpty();
        boolean leftMissing = left.isMissingNode() || left.isNull();
        boolean rightMissing = right.isMissingNode() || right.isNull();

        // If left is empty array and right missing (or vice versa), skip diff for this path
        if ((leftEmptyArray && rightMissing) || (rightEmptyArray && leftMissing)) {
            return; // treat as equal
        }

        // Handle null nodes and type differences first
//        if (isMissingOrNull(left) && isMissingOrNull(right)) {
//            return; // both absent/null → equal
//        }
//        if (isMissingOrNull(left) || isMissingOrNull(right)) {
//            // One is null/missing, other is not
//            recordChange(path, changes);
//            return;
//        }

        // Different node types → changed
        if (!left.getNodeType().equals(right.getNodeType())) {
            recordChange(path, changes);
            return;
        }

        switch (left.getNodeType()) {
            case OBJECT:
                diffObjects(left, right, path, changes);
                break;

            case ARRAY:
                diffArrays(left, right, path, changes);
                break;

            default:
                // Primitive values: direct compare
                if (!Objects.equals(left.asText(), right.asText())) {
                    recordChange(path, changes);
                }
        }
    }

    private static void diffObjects(JsonNode left, JsonNode right, String path, List<String> changes) {
        Set<String> fieldNames = collectFieldNames(left, right);

        for (String field : fieldNames) {
            String childPath = buildChildPath(path, field);

            if (shouldSkipField(field, childPath)) {
                continue;
            }

            JsonNode lChild = getChildNode(left, field);
            JsonNode rChild = getChildNode(right, field);

            if (shouldSkipEmptyArrayComparison(lChild, rChild)) {
                continue;
            }

            if (areBothMissing(lChild, rChild)) {
                continue;
            }

            if (isOneMissing(lChild, rChild)) {
                recordChange(childPath, changes);
                continue;
            }

            compareNodes(lChild, rChild, childPath, changes);
        }
    }

    private static Set<String> collectFieldNames(JsonNode left, JsonNode right) {
        Set<String> fieldNames = new TreeSet<>();
        left.fieldNames().forEachRemaining(fieldNames::add);
        right.fieldNames().forEachRemaining(fieldNames::add);
        return fieldNames;
    }

    private static String buildChildPath(String path, String field) {
        return path.isEmpty() ? field : path + "." + field;
    }

    private static boolean shouldSkipField(String field, String childPath) {
        return SKIP_FIELDS.contains(field) || SKIP_FIELDS.contains(childPath);
    }

    private static JsonNode getChildNode(JsonNode parent, String field) {
        JsonNode child = parent.has(field) ? parent.get(field) : MissingNode.getInstance();
        return child == null ? MissingNode.getInstance() : child;
    }

    private static boolean shouldSkipEmptyArrayComparison(JsonNode lChild, JsonNode rChild) {
        boolean lEmptyArr = lChild.isArray() && lChild.isEmpty();
        boolean rEmptyArr = rChild.isArray() && rChild.isEmpty();
        boolean lMissing = lChild.isMissingNode() || lChild.isNull();
        boolean rMissing = rChild.isMissingNode() || rChild.isNull();

        return (lEmptyArr && rMissing) || (rEmptyArr && lMissing);
    }

    private static boolean areBothMissing(JsonNode lChild, JsonNode rChild) {
        boolean lMissing = lChild.isMissingNode() || lChild.isNull();
        boolean rMissing = rChild.isMissingNode() || rChild.isNull();
        return lMissing && rMissing;
    }

    private static boolean isOneMissing(JsonNode lChild, JsonNode rChild) {
        boolean lMissing = lChild.isMissingNode() || lChild.isNull();
        boolean rMissing = rChild.isMissingNode() || rChild.isNull();
        return lMissing ^ rMissing;
    }

    private static void compareNodes(JsonNode lChild, JsonNode rChild, String childPath, List<String> changes) {
        if (lChild.getNodeType() != rChild.getNodeType()) {
            recordChange(childPath, changes);
            return;
        }

        if (lChild.isObject()) {
            diffObjects(lChild, rChild, childPath, changes);
        } else if (lChild.isArray()) {
            diffArrays(lChild, rChild, childPath, changes);
        } else if (!lChild.equals(rChild)) {
            recordChange(childPath, changes);
        }
    }

    private static void diffArrays(JsonNode left, JsonNode right, String path, List<String> changes) {

        // Defensive: treat empty array == missing/null
        boolean leftIsEmptyArray = left != null && left.isArray() && left.size() == 0;
        boolean rightIsEmptyArray = right != null && right.isArray() && right.size() == 0;
        boolean leftIsMissing = left == null || left.isMissingNode() || left.isNull();
        boolean rightIsMissing = right == null || right.isMissingNode() || right.isNull();

        if ((leftIsEmptyArray && rightIsMissing) || (rightIsEmptyArray && leftIsMissing)) {
            return; // no diff
        }

        int lSize = left.size();
        int rSize = right.size();

        if (lSize != rSize) {
            // Size difference is a change at the array path
            recordChange(path, changes);
        }

        // Compare overlapping indices
        int min = Math.min(lSize, rSize);
        for (int i = 0; i < min; i++) {
            String idxPath = path + "[" + i + "]";
            diffNodes(left.get(i), right.get(i), idxPath, changes);
        }
    }

    private static boolean isMissingOrNull(JsonNode node) {
        return node == null || node.isMissingNode() || node.isNull();
    }

    private static void recordChange(String path, List<String> changes) {
        // Empty path means the root differs; represent it as "$"
        changes.add(path == null || path.isEmpty() ? "$" : path);
    }


}
