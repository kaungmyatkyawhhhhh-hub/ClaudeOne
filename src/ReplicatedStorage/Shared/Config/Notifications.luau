-- Notifications (26 Oct, retention): Roblox experience notifications, "your daily reward is ready".
--  * Opt-in: after claiming a daily reward the player gets Roblox's own "turn on notifications?" prompt (DailyClient), once
--    a session, only if Roblox allows it (ExperienceNotificationService).
--  * Sending (Server/NotifyService): a player who leaves is queued (MemoryStore sorted map) for the next UTC day reset
--    (+ up to SpreadMinutes); any running server sends due ones through Open Cloud (user notifications API), with the API
--    key from the experience secret SecretName. Coming back removes you from the queue. Without the secret nothing is sent.
-- Owner: the message (Creator Hub > Engagement > Notifications) is MessageId; the API key needs the
-- "user.user-notification:write" permission for this experience and lives in Creator Hub > Secrets as SecretName
-- (domain apis.roblox.com).
local Notifications = {}

Notifications.MessageId = "c7200b38-2ab4-cc40-b4a3-8a0ab40d67fc" -- "daily reward ready" (owner, 26 Oct)
Notifications.SecretName = "notify_key"
Notifications.SpreadMinutes = 30   -- send between the reset and this many minutes after it (spreads the load)
Notifications.MaxAwayDays = 7      -- a queued reminder older than this is dropped (one reminder per visit)
Notifications.CheckSeconds = 60    -- how often a server looks for due reminders
Notifications.BatchSize = 25
Notifications.Category = "Daily reward"

return Notifications
