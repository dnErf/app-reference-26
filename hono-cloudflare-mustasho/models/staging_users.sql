SELECT {{columns}}
FROM {{source 'raw_users'}}
WHERE created_at > '{{var 'START_DATE'}}'
{{#if incremental}}
  AND updated_at > '{{var 'LAST_RUN'}}'
{{/if}}