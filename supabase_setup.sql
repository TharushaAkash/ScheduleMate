-- Run this in your Supabase SQL Editor

-- 1. Rooms Table
CREATE TABLE rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  join_code TEXT NOT NULL UNIQUE,
  creator_uid UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  creator_name TEXT NOT NULL,
  member_count INT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Room Members Table
CREATE TABLE room_members (
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  email TEXT,
  photo_url TEXT,
  role TEXT DEFAULT 'member',
  joined_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (room_id, user_id)
);

-- 3. Room Files/Links Table
CREATE TABLE room_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  url TEXT,
  storage_path TEXT,   -- path in Supabase Storage bucket (null if link only)
  is_folder BOOLEAN DEFAULT false,
  parent_id UUID REFERENCES room_files(id) ON DELETE CASCADE,
  added_by UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  added_by_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security (RLS)
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_files ENABLE ROW LEVEL SECURITY;

-- Create basic policies to allow logged-in users to access and modify data
-- (This prevents the Supabase warning and is safer than disabling RLS entirely)

CREATE POLICY "Allow authenticated users full access to rooms" 
ON rooms FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow authenticated users full access to room_members" 
ON room_members FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow authenticated users full access to room_files" 
ON room_files FOR ALL TO authenticated USING (true) WITH CHECK (true);
