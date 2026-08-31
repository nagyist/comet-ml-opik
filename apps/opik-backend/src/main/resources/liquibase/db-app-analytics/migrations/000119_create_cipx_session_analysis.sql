--liquibase formatted sql
--changeset andriid:000119_create_cipx_session_analysis
--comment: LLM session analysis results (phase segmentation), written by the cost API analysis runner

-- One row per session, replaced whole on re-analysis (newest analyzed_at wins).
-- No PARTITION BY on purpose: ReplacingMergeTree collapses duplicates only within a
-- partition. Design: ai-cost-backend docs/analysis-framework.md.
CREATE TABLE IF NOT EXISTS ${ANALYTICS_DB_DATABASE_NAME}.cipx_session_analysis ON CLUSTER '{cluster}'
(
    workspace_id  String,
    project_id    FixedString(36),
    user_uuid     String,
    session_id    String,

    task_version  UInt16,
    analyzed_at   DateTime64(6, 'UTC') DEFAULT now64(6),
    -- Raw developer-turn count at analysis time (the re-analysis growth watermark).
    source_turns  UInt32,

    `segments.start_turn`     Array(UInt32),
    `segments.end_turn`       Array(UInt32),
    -- Turn numbers index a filtered, renumbered sequence; the boundary trace ids
    -- anchor segments to real traces and survive any filter change.
    `segments.first_trace_id` Array(FixedString(36)),
    `segments.last_trace_id`  Array(FixedString(36)),
    `segments.phase`          Array(LowCardinality(String)),
    `segments.title`          Array(String)
)
ENGINE = ReplicatedReplacingMergeTree(
    '/clickhouse/tables/{shard}/${ANALYTICS_DB_DATABASE_NAME}/cipx_session_analysis',
    '{replica}',
    analyzed_at
)
ORDER BY (workspace_id, project_id, user_uuid, session_id);

--rollback DROP TABLE IF EXISTS ${ANALYTICS_DB_DATABASE_NAME}.cipx_session_analysis ON CLUSTER '{cluster}';
