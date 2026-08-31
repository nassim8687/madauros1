DO $$ BEGIN CREATE TYPE public.resource_category AS ENUM ('cours', 'exercices'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.teacher_classes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  class_id uuid NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (teacher_id, class_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.teacher_classes TO authenticated;
GRANT ALL ON public.teacher_classes TO service_role;
ALTER TABLE public.teacher_classes ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.teaches_student(_teacher_id uuid, _student_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    JOIN public.teacher_classes tc ON tc.class_id = p.class_id
    WHERE p.id = _student_id AND tc.teacher_id = _teacher_id
  )
$$;

CREATE TABLE IF NOT EXISTS public.resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  level_id uuid REFERENCES public.levels(id) ON DELETE SET NULL,
  category public.resource_category NOT NULL,
  title text NOT NULL,
  description text,
  file_path text NOT NULL,
  file_name text NOT NULL,
  mime_type text,
  file_size bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.resources TO authenticated;
GRANT ALL ON public.resources TO service_role;
ALTER TABLE public.resources ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS resources_level_category_idx ON public.resources (level_id, category);
DROP TRIGGER IF EXISTS update_resources_updated_at ON public.resources;
CREATE TRIGGER update_resources_updated_at BEFORE UPDATE ON public.resources FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE IF NOT EXISTS public.submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_id uuid NOT NULL REFERENCES public.resources(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  teacher_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  class_id uuid REFERENCES public.classes(id) ON DELETE SET NULL,
  level_id uuid REFERENCES public.levels(id) ON DELETE SET NULL,
  file_path text NOT NULL,
  file_name text NOT NULL,
  mime_type text,
  file_size bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.submissions TO authenticated;
GRANT ALL ON public.submissions TO service_role;
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS submissions_teacher_idx ON public.submissions(teacher_id);
CREATE INDEX IF NOT EXISTS submissions_student_idx ON public.submissions(student_id);
DROP TRIGGER IF EXISTS update_submissions_updated_at ON public.submissions;
CREATE TRIGGER update_submissions_updated_at BEFORE UPDATE ON public.submissions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE IF NOT EXISTS public.submission_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL REFERENCES public.submissions(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.submission_comments TO authenticated;
GRANT ALL ON public.submission_comments TO service_role;
ALTER TABLE public.submission_comments ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS submission_comments_submission_idx ON public.submission_comments(submission_id);

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  kind text NOT NULL,
  title text NOT NULL,
  body text,
  submission_id uuid REFERENCES public.submissions(id) ON DELETE CASCADE,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS notifications_user_idx ON public.notifications(user_id, read_at);

REVOKE ALL ON FUNCTION public.teaches_student(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.teaches_student(uuid, uuid) TO authenticated, service_role;

INSERT INTO public.levels (id, name, code, position) VALUES
  ('c72155c6-4a88-437a-81a5-be7d423c260e', 'السنة الأولى ثانوي جذع مشترك علوم و تكنولوجيا', '1ASS', 1),
  ('0ba2ce1f-d3ca-401c-98fa-dae727c4f467', 'السنة الأولى ثانوي جذع مشترك آداب', '1ASL', 2),
  ('b43b093d-668e-4e98-a334-f76761f548ba', 'السنة الثانية ثانوي شعب تسيير آداب و لغات', '2ASL', 3),
  ('de3b38fd-8654-45c0-aadc-ecdf83bc2a21', 'السنة الثانية ثانوي شعب علمي و رياضي', '2ASS', 4),
  ('5e2f95b4-d1fe-4c2c-ac45-726932c571bf', 'السنة الثالثة من التعليم الثانوي شعب علمي و رياضي', '3ASS', 5),
  ('fc05b399-430b-48a0-b1e0-08a4c04d8d74', 'السنة الثالثة ثانوي شعب آداب و لغات', '3ASL', 6),
  ('4f1ff455-82a9-4ce9-96e3-b3bd936dbac0', 'السنة الثالثة ثانوي شعب تسيير و إقتصاد', '3ASG', 7)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.classes (id, name, level_id, capacity) VALUES
  ('43ab7b73-9f1c-410f-baf2-d751d19981e9', '1أ1', 'c72155c6-4a88-437a-81a5-be7d423c260e', 1),
  ('26ccaad0-8ede-4f48-91de-e5324219be5a', '1ل1', '0ba2ce1f-d3ca-401c-98fa-dae727c4f467', 4),
  ('14d5f05a-ba92-46c7-af70-a59ec8a85dca', '2أ1', 'de3b38fd-8654-45c0-aadc-ecdf83bc2a21', 2),
  ('a68ff757-9449-4195-b07d-78d3e284d1a8', '3أ1', '5e2f95b4-d1fe-4c2c-ac45-726932c571bf', 3),
  ('a353d2ae-9889-49d6-87ff-1a5f0e27fce5', '3ت إ1', '4f1ff455-82a9-4ce9-96e3-b3bd936dbac0', 7),
  ('62265b10-a4fc-47c9-ae0c-a259ddf4fc0f', '2ل1', 'b43b093d-668e-4e98-a334-f76761f548ba', 5),
  ('90458272-66e5-464d-b48a-66f548ff8ff2', '3ل1', 'fc05b399-430b-48a0-b1e0-08a4c04d8d74', 6)
ON CONFLICT (id) DO NOTHING;