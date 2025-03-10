import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

export interface UploadState {
  files: File[];
  previews: string[];
  caption: string;
  hashtags: string[];
  mentions: string[];
  location: string;
  hideCounts: boolean;
  scheduledTime: Date | null;
  autoSaveId: string | null;
}

export function useUploadState() {
  const [state, setState] = useState<UploadState>({
    files: [],
    previews: [],
    caption: '',
    hashtags: [],
    mentions: [],
    location: '',
    hideCounts: false,
    scheduledTime: null,
    autoSaveId: null
  });

  const autoSave = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const draft = {
        files: state.files,
        caption: state.caption,
        hashtags: state.hashtags,
        mentions: state.mentions,
        location: state.location,
        hideCounts: state.hideCounts,
        scheduledTime: state.scheduledTime?.toISOString(),
        lastModified: new Date().toISOString()
      };

      if (state.autoSaveId) {
        await supabase
          .from('content_drafts')
          .update({ content: draft })
          .eq('id', state.autoSaveId);
      } else {
        const { data } = await supabase
          .from('content_drafts')
          .insert({ user_id: user.id, content: draft })
          .select()
          .single();

        if (data) {
          setState(prev => ({ ...prev, autoSaveId: data.id }));
        }
      }
    } catch (err) {
      console.error('Auto-save failed:', err);
    }
  };

  useEffect(() => {
    const interval = setInterval(autoSave, 30000);
    return () => clearInterval(interval);
  }, [state]);

  return {
    state,
    setState,
    autoSave
  };
}