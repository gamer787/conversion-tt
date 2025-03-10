import React, { useState, useEffect } from 'react';
import { Bluetooth, Smartphone, MapPin, Wifi, RotateCcw, Loader2, Radio, Compass } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { bluetoothScanner } from '../../lib/bluetooth';
import { nfcScanner } from '../../lib/nfc';
import { locationDiscovery } from '../../lib/location';

interface ConnectionPreference {
  type: string;
  enabled: boolean;
  description: string;
  lastUpdated: string | null;
}

interface LocationPreference {
  enabled: boolean;
  accuracy: 'high' | 'medium' | 'low';
  autoUpdate: boolean;
  shareWithFriends: boolean;
  lastUpdated: string | null;
}

interface ConnectionSettings {
  bluetooth: ConnectionPreference;
  nfc: ConnectionPreference;
  location: LocationPreference;
  backgroundSync: ConnectionPreference;
  autoConnect: ConnectionPreference;
}

const defaultSettings: ConnectionSettings = {
  bluetooth: {
    type: 'bluetooth',
    enabled: true,
    description: 'Discover nearby users using Bluetooth',
    lastUpdated: null
  },
  nfc: {
    type: 'nfc',
    enabled: true,
    description: 'Connect instantly with NFC tap',
    lastUpdated: null
  },
  location: {
    enabled: true,
    accuracy: 'high',
    autoUpdate: true,
    shareWithFriends: false,
    lastUpdated: null
  },
  backgroundSync: {
    type: 'backgroundSync',
    enabled: true,
    description: 'Keep discovering users while app is in background',
    lastUpdated: null
  },
  autoConnect: {
    type: 'autoConnect',
    enabled: false,
    description: 'Automatically connect with trusted users nearby',
    lastUpdated: null
  }
};

export function ConnectionSettings() {
  const [settings, setSettings] = useState<ConnectionSettings>(defaultSettings);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [scanning, setScanning] = useState(false);

  useEffect(() => {
    loadSettings();
    return () => {
      // Clean up scanning on unmount
      bluetoothScanner.stopScanning();
      nfcScanner.stopScanning();
      locationDiscovery.stopDiscovering();
    };
  }, []);

  const loadSettings = async () => {
    try {
      setLoading(true);
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      // Check NFC availability
      const nfcAvailable = await nfcScanner.isAvailable();
      if (!nfcAvailable) {
        // Disable NFC if not available
        defaultSettings.nfc.enabled = false;
        defaultSettings.nfc.description = 'NFC is not supported on this device';
      }

      const { data: profile } = await supabase
        .from('profiles')
        .select('connection_preferences')
        .eq('id', user.id)
        .single();

      if (profile?.connection_preferences) {
        setSettings(profile.connection_preferences);
        
        // Start services based on saved preferences
        if (profile.connection_preferences.bluetooth?.enabled) {
          bluetoothScanner.startScanning();
        }
        if (profile.connection_preferences.nfc?.enabled && nfcAvailable) {
          nfcScanner.startScanning();
        }
        if (profile.connection_preferences.location?.enabled) {
          locationDiscovery.startDiscovering();
        }
        setScanning(true);
      }
    } catch (err) {
      console.error('Error loading connection settings:', err);
      setError('Failed to load connection preferences');
    } finally {
      setLoading(false);
    }
  };

  const saveSettings = async (newSettings: ConnectionSettings) => {
    try {
      setSaving(true);
      setError(null);
      setSuccess(null);

      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { error: updateError } = await supabase
        .from('profiles')
        .update({
          connection_preferences: newSettings,
          updated_at: new Date().toISOString()
        })
        .eq('id', user.id);

      if (updateError) throw updateError;

      setSettings(newSettings);
      setSuccess('Connection preferences updated successfully');

      // Update scanning services
      if (newSettings.bluetooth.enabled !== settings.bluetooth.enabled) {
        if (newSettings.bluetooth.enabled) {
          bluetoothScanner.startScanning();
        } else {
          bluetoothScanner.stopScanning();
        }
      }

      if (newSettings.nfc.enabled !== settings.nfc.enabled) {
        const nfcAvailable = await nfcScanner.isAvailable();
        if (newSettings.nfc.enabled && nfcAvailable) {
          nfcScanner.startScanning();
        } else {
          nfcScanner.stopScanning();
        }
      }

      if (newSettings.location.enabled !== settings.location.enabled) {
        if (newSettings.location.enabled) {
          locationDiscovery.startDiscovering();
        } else {
          locationDiscovery.stopDiscovering();
        }
      }

      setScanning(newSettings.bluetooth.enabled || newSettings.nfc.enabled || newSettings.location.enabled);
    } catch (err) {
      console.error('Error saving connection settings:', err);
      setError('Failed to save connection preferences');
    } finally {
      setSaving(false);
    }
  };

  const handleToggle = async (key: keyof ConnectionSettings) => {
    if (key === 'location') {
      const newSettings = {
        ...settings,
        location: {
          ...settings.location,
          enabled: !settings.location.enabled,
          lastUpdated: new Date().toISOString()
        }
      };
      await saveSettings(newSettings);
    } else {
      const newSettings = {
        ...settings,
        [key]: {
          ...settings[key],
          enabled: !settings[key].enabled,
          lastUpdated: new Date().toISOString()
        }
      };
      await saveSettings(newSettings);
    }
  };

  const handleLocationAccuracyChange = async (accuracy: 'high' | 'medium' | 'low') => {
    const newSettings = {
      ...settings,
      location: {
        ...settings.location,
        accuracy,
        lastUpdated: new Date().toISOString()
      }
    };
    await saveSettings(newSettings);
  };

  const handleResetDefaults = async () => {
    await saveSettings({
      ...defaultSettings,
      ...Object.keys(defaultSettings).reduce((acc, key) => ({
        ...acc,
        [key]: {
          ...defaultSettings[key as keyof ConnectionSettings],
          lastUpdated: new Date().toISOString()
        }
      }), {})
    });
  };

  const getIcon = (type: string) => {
    switch (type) {
      case 'bluetooth':
        return <Bluetooth className="w-5 h-5" />;
      case 'nfc':
        return <Smartphone className="w-5 h-5" />;
      case 'backgroundSync':
        return <Radio className="w-5 h-5" />;
      case 'autoConnect':
        return <Wifi className="w-5 h-5" />;
      default:
        return <Bluetooth className="w-5 h-5" />;
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
        <div>
          <h2 className="text-lg font-semibold">Connection Settings</h2>
          {scanning && (
            <div className="flex items-center mt-1 text-sm text-cyan-400">
              <div className="w-2 h-2 bg-cyan-400 rounded-full mr-2 animate-pulse" />
              Scanning for nearby users...
            </div>
          )}
        </div>
        <button
          onClick={handleResetDefaults}
          className="text-sm bg-gray-800 text-white px-3 py-1 rounded-lg hover:bg-gray-700 transition-colors flex items-center space-x-1"
        >
          <RotateCcw className="w-4 h-4" />
          <span>Reset</span>
        </button>
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

      {/* Connection Settings */}
      <div className="space-y-4">
        {Object.entries(settings).map(([key, setting]) => {
          if (key === 'location') {
            return (
              <div key={key} className="bg-gray-900 p-4 rounded-lg space-y-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-4">
                    <div className={`p-2 rounded-full ${
                      setting.enabled ? 'bg-cyan-400/10 text-cyan-400' : 'bg-gray-800 text-gray-400'
                    }`}>
                      <MapPin className="w-5 h-5" />
                    </div>
                    <div>
                      <h3 className="font-medium">Location Services</h3>
                      <p className="text-sm text-gray-400">Share and update your location</p>
                      {setting.lastUpdated && (
                        <p className="text-xs text-gray-500 mt-1">
                          Last updated: {new Date(setting.lastUpdated).toLocaleDateString()}
                        </p>
                      )}
                    </div>
                  </div>
                  <button
                    onClick={() => handleToggle('location')}
                    disabled={saving}
                    className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-cyan-400 focus:ring-offset-2 focus:ring-offset-gray-900 ${
                      setting.enabled ? 'bg-cyan-400' : 'bg-gray-700'
                    }`}
                    role="switch"
                    aria-checked={setting.enabled}
                    aria-label="Toggle location services"
                  >
                    <span
                      className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                        setting.enabled ? 'translate-x-6' : 'translate-x-1'
                      }`}
                    />
                  </button>
                </div>

                {setting.enabled && (
                  <div className="pl-14 space-y-4">
                    <div>
                      <label className="text-sm font-medium text-gray-400">Location Accuracy</label>
                      <div className="mt-2 grid grid-cols-3 gap-2">
                        {['high', 'medium', 'low'].map((accuracy) => (
                          <button
                            key={accuracy}
                            onClick={() => handleLocationAccuracyChange(accuracy as 'high' | 'medium' | 'low')}
                            className={`px-3 py-1 rounded-lg text-sm font-medium transition-colors ${
                              setting.accuracy === accuracy
                                ? 'bg-cyan-400 text-gray-900'
                                : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
                            }`}
                          >
                            {accuracy.charAt(0).toUpperCase() + accuracy.slice(1)}
                          </button>
                        ))}
                      </div>
                    </div>

                    <div className="flex items-center justify-between">
                      <div>
                        <h4 className="text-sm font-medium">Auto-Update Location</h4>
                        <p className="text-xs text-gray-400">Update location in background</p>
                      </div>
                      <button
                        onClick={() => {
                          const newSettings = {
                            ...settings,
                            location: {
                              ...settings.location,
                              autoUpdate: !settings.location.autoUpdate,
                              lastUpdated: new Date().toISOString()
                            }
                          };
                          saveSettings(newSettings);
                        }}
                        className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-cyan-400 focus:ring-offset-2 focus:ring-offset-gray-900 ${
                          setting.autoUpdate ? 'bg-cyan-400' : 'bg-gray-700'
                        }`}
                      >
                        <span
                          className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                            setting.autoUpdate ? 'translate-x-6' : 'translate-x-1'
                          }`}
                        />
                      </button>
                    </div>

                    <div className="flex items-center justify-between">
                      <div>
                        <h4 className="text-sm font-medium">Share with Friends</h4>
                        <p className="text-xs text-gray-400">Let friends see your location</p>
                      </div>
                      <button
                        onClick={() => {
                          const newSettings = {
                            ...settings,
                            location: {
                              ...settings.location,
                              shareWithFriends: !settings.location.shareWithFriends,
                              lastUpdated: new Date().toISOString()
                            }
                          };
                          saveSettings(newSettings);
                        }}
                        className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-cyan-400 focus:ring-offset-2 focus:ring-offset-gray-900 ${
                          setting.shareWithFriends ? 'bg-cyan-400' : 'bg-gray-700'
                        }`}
                      >
                        <span
                          className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                            setting.shareWithFriends ? 'translate-x-6' : 'translate-x-1'
                          }`}
                        />
                      </button>
                    </div>
                  </div>
                )}
              </div>
            );
          }

          return (
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
                    {key === 'backgroundSync' ? 'Background Sync' : 
                     key === 'autoConnect' ? 'Auto Connect' : 
                     key.toUpperCase()}
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
                onClick={() => handleToggle(key as keyof ConnectionSettings)}
                disabled={saving}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-cyan-400 focus:ring-offset-2 focus:ring-offset-gray-900 ${
                  setting.enabled ? 'bg-cyan-400' : 'bg-gray-700'
                }`}
                role="switch"
                aria-checked={setting.enabled}
                aria-label={`Toggle ${key}`}
              >
                <span
                  className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                    setting.enabled ? 'translate-x-6' : 'translate-x-1'
                  }`}
                />
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}