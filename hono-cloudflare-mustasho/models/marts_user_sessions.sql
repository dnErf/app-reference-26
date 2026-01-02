SELECT user_id, COUNT(*) as sessions
FROM {{ref 'staging_users'}}
{{#if (config 'filter_active')}}
WHERE is_active = true
{{/if}}
GROUP BY user_id