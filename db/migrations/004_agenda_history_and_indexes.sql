-- SocialMEI: preserve reminder status history.
-- Additive migration; does not alter existing reminder records.
BEGIN;

CREATE TABLE IF NOT EXISTS socialmei.agenda_reminder_history (
  workspace_id bigint NOT NULL,
  reminder_id uuid NOT NULL,
  revision bigint NOT NULL CHECK (revision >= 1),
  scheduled_for timestamptz NOT NULL,
  status text NOT NULL CHECK (status IN ('pending','done','cancelled')),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (workspace_id, reminder_id, revision),
  CONSTRAINT agenda_reminder_history_reminder_fk
    FOREIGN KEY (workspace_id, reminder_id)
    REFERENCES socialmei.agenda_reminders(workspace_id, id)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS agenda_appointments_resource_time_idx
  ON socialmei.agenda_appointments (workspace_id, resource_id, scheduled_for)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS agenda_reminders_workspace_time_idx
  ON socialmei.agenda_reminders (workspace_id, scheduled_for);

COMMIT;
