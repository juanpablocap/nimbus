-- Notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'general', -- general | visit | news | access
  reference_id UUID, -- optional: visit_id, news_id, etc.
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast unread count queries
CREATE INDEX IF NOT EXISTS notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own notifications"
  ON notifications FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can mark their own notifications as read"
  ON notifications FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Service role can insert notifications
CREATE POLICY "Service role can insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (TRUE);

-- Trigger: create notifications for all community residents when news is published
CREATE OR REPLACE FUNCTION notify_on_news_publish()
RETURNS TRIGGER AS $$
BEGIN
  -- Only fire when is_published flips to TRUE
  IF NEW.is_published = TRUE AND (OLD.is_published IS NULL OR OLD.is_published = FALSE) THEN
    INSERT INTO notifications (community_id, user_id, title, body, type, reference_id)
    SELECT
      NEW.community_id,
      p.id,
      NEW.title,
      LEFT(NEW.body, 120),
      'news',
      NEW.id
    FROM profiles p
    WHERE p.community_id = NEW.community_id
      AND p.role = 'resident';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_news_published ON news;
CREATE TRIGGER on_news_published
  AFTER INSERT OR UPDATE ON news
  FOR EACH ROW EXECUTE FUNCTION notify_on_news_publish();
