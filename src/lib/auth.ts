import { supabase } from './supabase';
import type { Profile } from '../types/database';

export async function checkUsernameAvailability(username: string) {
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('username')
      .eq('username', username.toLowerCase())
      .maybeSingle();

    if (error) {
      return { available: false, error: error.message };
    }

    return { available: !data, error: null };
  } catch (err) {
    return { available: false, error: 'Error checking username availability' };
  }
}

export async function signUp(data: {
  email: string;
  password: string;
  username: string;
  displayName: string;
  accountType: 'personal' | 'business';
  location?: string;
  website?: string;
  bio?: string;
  industry?: string;
  phone?: string;
}) {
  try {
    // Check if user already exists
    const { data: existingUser, error: checkError } = await supabase.auth.signInWithPassword({
      email: data.email,
      password: data.password,
    });

    if (!checkError && existingUser.user) {
      return { user: null, error: new Error('Email already registered. Please sign in instead.') };
    }

    // Check username availability
    const { available, error: usernameError } = await checkUsernameAvailability(data.username);
    if (!available) {
      throw new Error(usernameError || 'Username is not available');
    }

    // Create auth user
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email: data.email,
      password: data.password,
      options: {
        data: {
          username: data.username.toLowerCase(),
          display_name: data.displayName,
          account_type: data.accountType,
        },
      },
    });

    if (authError) throw authError;
    if (!authData.user) throw new Error('No user returned after signup');

    // Create profile with proper account type and fields
    const profileData = {
      id: authData.user.id,
      username: data.username.toLowerCase(),
      display_name: data.displayName,
      account_type: data.accountType,
      location: data.location || null,
      website: data.website || null,
      bio: data.bio || null,
      // Only include business fields if it's a business account
      ...(data.accountType === 'business' ? {
        industry: data.industry || null,
        phone: data.phone || null,
      } : {
        industry: null,
        phone: null,
      }),
    };

    const { error: profileError } = await supabase
      .from('profiles')
      .insert(profileData);

    if (profileError) throw profileError;

    return { user: authData.user, error: null };
  } catch (error) {
    return { user: null, error };
  }
}

export async function signIn(identifier: string, password: string) {
  try {
    // Try email login first
    const { data, error: emailError } = await supabase.auth.signInWithPassword({
      email: identifier,
      password,
    });

    if (!emailError) return { data, error: null };

    // If email login failed, try username
    const { data: profiles } = await supabase
      .from('profiles')
      .select('id, email')
      .eq('username', identifier.toLowerCase())
      .limit(1);

    if (!profiles || profiles.length === 0) {
      return { data: { user: null }, error: new Error('Invalid username or password') };
    }

    // Try to sign in with the found profile's email
    const { data: userData, error: authError } = await supabase.auth.signInWithPassword({
      email: profiles[0].email || identifier,
      password,
    });

    if (authError || !userData.user) {
      return { data: { user: null }, error: new Error('Invalid username or password') };
    }

    return { data: userData, error: null };
  } catch (err) {
    return { data: { user: null }, error: new Error('Invalid username or password') };
  }
}

export async function signOut() {
  return await supabase.auth.signOut();
}

export async function getCurrentProfile(): Promise<{ profile: Profile | null; error: Error | null }> {
  try {
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError) throw authError;
    if (!user) return { profile: null, error: new Error('Not authenticated') };

    // Get profile with all fields including business-specific ones
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .maybeSingle();

    if (profileError) {
      if (profileError.code === 'PGRST116') {
        // Profile doesn't exist, create one
        const { data: newProfile, error: createError } = await supabase
          .from('profiles')
          .insert({
            id: user.id,
            username: user.email?.split('@')[0] || `user_${Math.random().toString(36).slice(2, 7)}`,
            display_name: user.email?.split('@')[0] || 'New User',
            account_type: 'personal',
            industry: null,
            phone: null
          })
          .select()
          .single();

        if (createError) throw createError;
        return { profile: newProfile, error: null };
      }
      throw profileError;
    }

    if (!profile) {
      return { profile: null, error: new Error('Profile not found') };
    }
    return { profile, error: null };
  } catch (error) {
    return { profile: null, error: error instanceof Error ? error : new Error('Unknown error') };
  }
}

export async function updateProfile(profile: Partial<Profile>) {
  try {
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError) throw authError;
    if (!user) throw new Error('Not authenticated');

    // Get current profile to check account type
    const { data: currentProfile, error: profileError } = await supabase
      .from('profiles')
      .select('account_type')
      .eq('id', user.id)
      .maybeSingle();

    if (profileError) throw profileError;

    // Only allow updating business fields if it's a business account
    const updateData = {
      ...profile,
      updated_at: new Date().toISOString(),
      // Remove business fields if it's a personal account
      ...(currentProfile.account_type === 'personal' ? {
        industry: null,
        phone: null,
      } : {}),
    };

    const { data, error } = await supabase
      .from('profiles')
      .update(updateData)
      .eq('id', user.id)
      .select()
      .single();

    if (error) throw error;
    return { profile: data, error: null };
  } catch (error) {
    return { profile: null, error: error instanceof Error ? error : new Error('Failed to update profile') };
  }
}