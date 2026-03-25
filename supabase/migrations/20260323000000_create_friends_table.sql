-- Create the friends table to store friendships between users
CREATE TABLE public.friends (
    user_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, friend_id),
    CONSTRAINT not_self CHECK (user_id != friend_id)
);

-- Index for quick lookups of a user's friends
CREATE INDEX friends_user_id_idx ON public.friends (user_id);
