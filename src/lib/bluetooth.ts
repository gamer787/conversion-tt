import { supabase } from './supabase';

export interface BluetoothUser {
  id: string;
  username: string;
  display_name: string;
  avatar_url: string | null;
  account_type: 'personal' | 'business';
  last_seen: Date;
}

class BluetoothScanner {
  private scanning: boolean = false;
  private onUserDiscovered: ((user: BluetoothUser) => void) | null = null;
  private onError: ((error: string) => void) | null = null;
  private discoveredUsers: Map<string, BluetoothUser> = new Map();
  private scanInterval: number | null = null;
  private discoveryInterval: number | null = null;
  private autoRetry: boolean = false;
  private backgroundMode: boolean = false;
  private deviceId: string | null = null;

  async isAvailable(): Promise<boolean> {
    if (!navigator.bluetooth) {
      throw new Error('Bluetooth is not supported on this device');
    }

    if (!window.isSecureContext) {
      throw new Error('Bluetooth scanning requires a secure (HTTPS) connection');
    }

    try {
      if ('getAvailability' in navigator.bluetooth) {
        const available = await navigator.bluetooth.getAvailability();
        if (!available) {
          throw new Error('Please enable Bluetooth on your device');
        }
      }
      return true;
    } catch (error) {
      console.error('Bluetooth availability check failed:', error);
      return false;
    }
  }

  setOnUserDiscovered(callback: (user: BluetoothUser) => void) {
    this.onUserDiscovered = callback;
  }

  setOnError(callback: (error: string) => void) {
    this.onError = callback;
  }

  setBackgroundMode(enabled: boolean) {
    this.backgroundMode = enabled;
    if (enabled) {
      // Increase scan interval in background mode to save battery
      if (this.scanInterval) {
        clearInterval(this.scanInterval);
        this.scanInterval = window.setInterval(async () => {
          if (this.scanning) {
            await this.performScan();
          }
        }, 30000); // Scan every 30 seconds in background
      }
    } else {
      // Reset to normal scan interval
      if (this.scanInterval) {
        clearInterval(this.scanInterval);
        this.scanInterval = window.setInterval(async () => {
          if (this.scanning) {
            await this.performScan();
          }
        }, 10000); // Scan every 10 seconds in foreground
      }
    }
  }

  private generateDeviceId(): string {
    return `${Math.random().toString(36).substring(2)}_${Date.now()}`;
  }

  async startScanning(autoRetry: boolean = false) {
    if (this.scanning) return;

    try {
      const isAvailable = await this.isAvailable();
      if (!isAvailable) {
        throw new Error('Bluetooth is not available');
      }

      this.scanning = true;
      this.autoRetry = autoRetry;
      this.discoveredUsers.clear();

      // Generate a new device ID for this scanning session
      this.deviceId = this.generateDeviceId();

      // Start continuous scanning
      await this.startContinuousScanning();
      
      // Start user discovery from database
      await this.startUserDiscovery();
    } catch (error) {
      this.scanning = false;
      const errorMessage = error instanceof Error ? error.message : 'Failed to start Bluetooth scanning';
      if (this.onError) {
        this.onError(errorMessage);
      }
      
      if (this.autoRetry && error instanceof Error && 
         (error.message.includes('permission') || error.message.includes('bluetooth'))) {
        setTimeout(() => {
          if (!this.scanning) {
            this.startScanning(true).catch(console.error);
          }
        }, 5000);
      } else {
        throw error;
      }
    }
  }

  private async performScan() {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      try {
        // Request Bluetooth permissions without showing device picker
        await navigator.bluetooth.getAvailability();

        // Simulate device discovery by updating last_seen
        await supabase
          .from('discovered_users')
          .upsert({
            discoverer_id: user.id,
            discovered_id: user.id,
            bluetooth_id: 'active_user',
            last_seen: new Date().toISOString()
          }, {
            onConflict: 'discoverer_id,discovered_id'
          });

      } catch (error) {
        if (error instanceof Error && 
            !error.message.includes('User cancelled') && 
            !error.message.includes('permission') &&
            !error.message.includes('cancelled')) {
          throw error;
        }
      }
    } catch (error) {
      if (error instanceof Error && 
          !error.message.includes('User cancelled') && 
          !error.message.includes('permission') &&
          !error.message.includes('cancelled')) {
        if (this.onError) {
          this.onError(error.message);
        }
      }
    }
  }

  private async startContinuousScanning() {
    if (this.scanInterval) {
      clearInterval(this.scanInterval);
      this.scanInterval = null;
    }

    // Perform initial scan
    await this.performScan();

    // Set up periodic scanning
    this.scanInterval = window.setInterval(async () => {
      if (this.scanning) {
        await this.performScan();
      }
    }, this.backgroundMode ? 30000 : 10000);
  }

  private async startUserDiscovery() {
    if (this.discoveryInterval) {
      clearInterval(this.discoveryInterval);
      this.discoveryInterval = null;
    }

    const discoverUsers = async () => {
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) return;

        // Get all nearby users and friends
        const [{ data: nearbyUsers, error }, { data: friends }] = await Promise.all([
          // Get nearby users from discovered_users table
          supabase
          .from('discovered_users')
          .select(`
            discovered_id,
            profiles!discovered_users_discovered_id_fkey (
              id,
              username,
              display_name,
              avatar_url,
              account_type
            )
          `)
          .neq('discovered_id', user.id)
          .gt('last_seen', new Date(Date.now() - 60000).toISOString()),
          
          // Get friends from accepted friend requests
          supabase
            .from('friend_requests')
            .select(`
              sender:profiles!friend_requests_sender_id_fkey (
                id,
                username,
                display_name,
                avatar_url,
                account_type
              ),
              receiver:profiles!friend_requests_receiver_id_fkey (
                id,
                username,
                display_name,
                avatar_url,
                account_type
              )
            `)
            .eq('status', 'accepted')
            .or(`sender_id.eq.${user.id},receiver_id.eq.${user.id}`)
        ]);

        if (error) {
          console.error('Error fetching nearby users:', error);
          return;
        }

        // Process nearby users
        nearbyUsers?.forEach(nearby => {
          if (nearby.profiles) {
            const user: BluetoothUser = {
              id: nearby.profiles.id,
              username: nearby.profiles.username,
              display_name: nearby.profiles.display_name,
              avatar_url: nearby.profiles.avatar_url,
              account_type: nearby.profiles.account_type,
              last_seen: new Date(),
              is_friend: false
            };

            this.discoveredUsers.set(user.id, user);
            
            if (this.onUserDiscovered) {
              this.onUserDiscovered(user);
            }
          }
        });

        // Process friends and add them to discovered users if they're nearby
        friends?.forEach(friend => {
          const friendProfile = friend.sender.id === user.id ? friend.receiver : friend.sender;
          
          // Check if this friend is also nearby (in discovered_users)
          const isNearby = nearbyUsers?.some(nearby => 
            nearby.discovered_id === friendProfile.id
          );

          if (isNearby) {
            const friendUser: BluetoothUser = {
              id: friendProfile.id,
              username: friendProfile.username,
              display_name: friendProfile.display_name,
              avatar_url: friendProfile.avatar_url,
              account_type: friendProfile.account_type,
              last_seen: new Date(),
              is_friend: true
            };

            this.discoveredUsers.set(friendProfile.id, friendUser);
            
            if (this.onUserDiscovered) {
              this.onUserDiscovered(friendUser);
            }
          }
        });

        // Clean up old users after 24 hours
        const twentyFourHoursAgo = Date.now() - (24 * 60 * 60 * 1000);
        this.discoveredUsers.forEach((user, id) => {
          if (user.last_seen.getTime() < twentyFourHoursAgo) {
            this.discoveredUsers.delete(id);
          }
        });
      } catch (error) {
        console.error('Error discovering users:', error);
      }
    };

    // Start immediate discovery
    await discoverUsers();

    // Set up periodic discovery
    this.discoveryInterval = window.setInterval(async () => {
      if (this.scanning) {
        await discoverUsers();
      }
    }, 3000); // Check every 3 seconds
  }

  stopScanning() {
    this.scanning = false;
    this.autoRetry = false;
    this.discoveredUsers.clear();
    this.deviceId = null;
    
    if (this.scanInterval) {
      clearInterval(this.scanInterval);
      this.scanInterval = null;
    }
    
    if (this.discoveryInterval) {
      clearInterval(this.discoveryInterval);
      this.discoveryInterval = null;
    }
  }

  getDiscoveredUsers(): BluetoothUser[] {
    return Array.from(this.discoveredUsers.values());
  }
}

export const bluetoothScanner = new BluetoothScanner();