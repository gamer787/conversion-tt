import React, { useState, useEffect } from 'react';
import { Bell, Mail, Smartphone, Shield, Activity, Megaphone, Check, X, Loader2, RotateCcw } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface NotificationPreference {
  type: string;
  enabled: boolean;
  description: string;
  lastUpdated: string | null;
}

interface NotificationSettings {
  email: NotificationPreference;
  push: NotificationPreference;
  inApp: NotificationPreference;
  marketing: NotificationPreference;
  security: NotificationPreference;
  activity: NotificationPreference;
}

const defaultSettings: NotificationSettings = {
  email: {
    type: 'email',
    enabled: true,
    description: 'Receive important updates and notifications via email',
    lastUpdated: null
  },
  push: {
    type: 'push',
    enabled: true,
    description: 'Get instant notifications on your device',
    lastUpdated: null
  },
  inApp: {
    type: 'inApp',
    enabled: true,
    description: 'See notifications within the app',
    lastUpdated: null
  },
  marketing: {
    type: 'marketing',
    enabled: false,
    description: 'Receive updates about new features and promotions',
    lastUpdated: null
  },
  security: {
    type: 'security',
    enabled: true,
    description: 'Get alerts about security-related activities',
    lastUpdated: null
  },
  activity: {
    type: 'activity',
    enabled: true,
    description: 'Stay informed about account activity and changes',
    lastUpdated: null
  }
};

export function NotificationSettings() {
  const [settings, setSettings] = useState<NotificationSettings>(defaultSettings);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    try {
      setLoading(true);
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { data: profile } = await supabase
        .from('profiles')
        .select('notification_preferences')
        .eq('id', user.id)
        .single();

      if (profile?.notification_preferences) {
        setSettings(profile.notification_preferences);
      }
    } catch (err) {
      console.error('Error loading notification settings:', err);
      setError('Failed to load notification preferences');
    } finally {
      setLoading(false);
    }
  };

  const saveSettings = async (newSettings: NotificationSettings) => {
    try {
      setSaving(true);
      setError(null);
      setSuccess(null);

      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { error: updateError } = await supabase
        .from('profiles')
        .update({
          notification_preferences: newSettings,
          updated_at: new Date().toISOString()
        })
        .eq('id', user.id);

      if (updateError) throw updateError;

      setSettings(newSettings);
      setSuccess('Notification preferences updated successfully');
    } catch (err) {
      console.error('Error saving notification settings:', err);
      setError('Failed to save notification preferences');
    } finally {
      setSaving(false);
    }
  };

  const handleToggle = async (key: keyof NotificationSettings) => {
    const newSettings = {
      ...settings,
      [key]: {
        ...settings[key],
        enabled: !settings[key].enabled,
        lastUpdated: new Date().toISOString()
      }
    };
    await saveSettings(newSettings);
  };

  const handleBulkToggle = async (enabled: boolean) => {
    const newSettings = Object.keys(settings).reduce((acc, key) => ({
      ...acc,
      [key]: {
        ...settings[key as keyof NotificationSettings],
        enabled,
        lastUpdated: new Date().toISOString()
      }
    }), {} as NotificationSettings);
    await saveSettings(newSettings);
  };

  const handleResetDefaults = async () => {
    const newSettings = {
      ...defaultSettings,
      ...Object.keys(defaultSettings).reduce((acc, key) => ({
        ...acc,
        [key]: {
          ...defaultSettings[key as keyof NotificationSettings],
          lastUpdated: new Date().toISOString()
        }
      }), {})
    };
    await saveSettings(newSettings);
  };

  const getIcon = (type: string) => {
    switch (type) {
      case 'email':
        return <Mail className="w-5 h-5" />;
      case 'push':
        return <Smartphone className="w-5 h-5" />;
      case 'inApp':
        return <Bell className="w-5 h-5" />;
      case 'marketing':
        return <Megaphone className="w-5 h-5" />;
      case 'security':
        return <Shield className="w-5 h-5" />;
      case 'activity':
        return <Activity className="w-5 h-5" />;
      default:
        return <Bell className="w-5 h-5" />;
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-8">
        <Loader2 className="w-8 h-8 animate-spin text-cyan-400" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">Notification Preferences</h2>
        <div className="flex items-center space-x-2">
          <button
            onClick={() => handleBulkToggle(true)}
            className="text-sm bg-gray-800 text-white px-3 py-1 rounded-lg hover:bg-gray-700 transition-colors"
          >
            Enable All
          </button>
          <button
            onClick={() => handleBulkToggle(false)}
            className="text-sm bg-gray-800 text-white px-3 py-1 rounded-lg hover:bg-gray-700 transition-colors"
          >
            Disable All
          </button>
          <button
            onClick={handleResetDefaults}
            className="text-sm bg-gray-800 text-white px-3 py-1 rounded-lg hover:bg-gray-700 transition-colors flex items-center space-x-1"
          >
            <RotateCcw className="w-4 h-4" />
            <span>Reset</span>
          </button>
        </div>
      </div>

      {/* Status Messages */}
      {error && (
        <div className="bg-red-400/10 border border-red-400 text-red-400 px-4 py-2 rounded-lg">
          {error}
        </div>
      )}
      {success && (
        <div className="bg-green-400/10 border border-green-400 text-green-400 px-4 py-2 rounded-lg">
          {success}
        </div>
      )}

      {/* Settings List */}
      <div className="space-y-4">
        {Object.entries(settings).map(([key, setting]) => (
          <div
            key={key}
            className="bg-gray-900 p-4 rounded-lg flex items-center justify-between"
          >
            <div className="flex items-center space-x-4">
              <div className={`p-2 rounded-full ${
                setting.enabled ? 'bg-cyan-400/10 text-cyan-400' : 'bg-gray-800 text-gray-400'
              }`}>
                {getIcon(setting.type)}
              </div>
              <div>
                <h3 className="font-medium capitalize">
                  {key === 'inApp' ? 'In-App' : key} Notifications
                </h3>
                <p className="text-sm text-gray-400">{setting.description}</p>
                {setting.lastUpdated && (
                  <p className="text-xs text-gray-500 mt-1">
                    Last updated: {new Date(setting.lastUpdated).toLocaleDateString()}
                  </p>
                )}
              </div>
            </div>
            <button
              onClick={() => handleToggle(key as keyof NotificationSettings)}
              disabled={saving}
              className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-cyan-400 focus:ring-offset-2 focus:ring-offset-gray-900 ${
                setting.enabled ? 'bg-cyan-400' : 'bg-gray-700'
              }`}
              role="switch"
              aria-checked={setting.enabled}
              aria-label={`Toggle ${key} notifications`}
            >
              <span
                className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                  setting.enabled ? 'translate-x-6' : 'translate-x-1'
                }`}
              />
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}