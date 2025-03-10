import { supabase } from './supabase';

export interface LocationUser {
  id: string;
  username: string;
  display_name: string;
  avatar_url: string | null;
  account_type: 'personal' | 'business';
  distance: number;
  last_seen: Date;
}

class LocationDiscovery {
  private discovering: boolean = false;
  private onUserDiscovered: ((user: LocationUser) => void) | null = null;
  private onError: ((error: string) => void) | null = null;
  private watchId: number | null = null;
  private discoveryInterval: number | null = null;
  private undiscoveredUsers: Map<string, LocationUser> = new Map();
  private lastSeenTimes: Map<string, number> = new Map();

  setOnUserDiscovered(callback: (user: LocationUser) => void) {
    this.onUserDiscovered = callback;
  }

  setOnError(callback: (error: string) => void) {
    this.onError = callback;
  }

  async startDiscovering() {
    if (this.discovering) {
      return;
    }

    try {
      if (!navigator.geolocation) {
        throw new Error('Geolocation is not supported by your browser');
      }

      this.discovering = true;

      // Start watching location
      this.watchId = navigator.geolocation.watchPosition(
        async (position) => {
          await this.updateLocation(position.coords);
        },
        (error) => {
          if (this.onError) {
            this.onError(this.getGeolocationErrorMessage(error));
          }
        },
        {
          enableHighAccuracy: true,
          timeout: 5000,
          maximumAge: 0
        }
      );

      // Start discovering nearby users
      await this.startUserDiscovery();

    } catch (error) {
      this.discovering = false;
      const errorMessage = error instanceof Error ? error.message : 'Failed to start location discovery';
      if (this.onError) {
        this.onError(errorMessage);
      }
      throw error;
    }
  }

  private async updateLocation(coords: GeolocationCoordinates) {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      await supabase
        .from('profiles')
        .update({
          latitude: coords.latitude,
          longitude: coords.longitude,
          location_updated_at: new Date().toISOString()
        })
        .eq('id', user.id);

    } catch (error) {
      console.error('Error updating location:', error);
    }
  }

  private async startUserDiscovery() {
    if (this.discoveryInterval) {
      clearInterval(this.discoveryInterval);
    }

    const discoverNearbyUsers = async () => {
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) return;

        // Get current user's location
        const { data: currentUser } = await supabase
          .from('profiles')
          .select('latitude, longitude')
          .eq('id', user.id)
          .single();

        if (!currentUser?.latitude || !currentUser?.longitude) return;

        // Find users within 500 feet (approximately 152.4 meters) who updated their location in the last 24 hours
        const { data: nearbyUsers } = await supabase.rpc('find_nearby_users', {
          user_lat: currentUser.latitude,
          user_lon: currentUser.longitude,
          max_distance: 0.1524, // 500 feet in kilometers
          hours_threshold: 24
        });

        const currentTime = Date.now();

        nearbyUsers?.forEach(nearby => {
          if (nearby && this.onUserDiscovered) {
            const user: LocationUser = {
              id: nearby.id,
              username: nearby.username,
              display_name: nearby.display_name,
              avatar_url: nearby.avatar_url,
              account_type: nearby.account_type,
              distance: nearby.distance * 1000, // Convert to meters
              last_seen: new Date(nearby.location_updated_at)
            };

            // Update last seen time for users in range
            this.lastSeenTimes.set(user.id, currentTime);

            // Add to undiscovered users if not already discovered
            if (!this.undiscoveredUsers.has(user.id)) {
              this.undiscoveredUsers.set(user.id, user);
              if (this.onUserDiscovered) {
                this.onUserDiscovered(user);
              }
            }
          }
        });

        // Clean up users that haven't been seen in 24 hours
        const twentyFourHoursAgo = currentTime - (24 * 60 * 60 * 1000);
        this.undiscoveredUsers.forEach((user, id) => {
          const lastSeen = this.lastSeenTimes.get(id) || 0;
          if (lastSeen < twentyFourHoursAgo) {
            this.undiscoveredUsers.delete(id);
            this.lastSeenTimes.delete(id);
          }
        });

      } catch (error) {
        console.error('Error discovering nearby users:', error);
      }
    };

    // Start immediate discovery
    await discoverNearbyUsers();

    // Set up periodic discovery
    this.discoveryInterval = window.setInterval(async () => {
      if (this.discovering) {
        await discoverNearbyUsers();
      }
    }, 30000); // Check every 30 seconds
  }

  private getGeolocationErrorMessage(error: GeolocationPositionError): string {
    switch (error.code) {
      case error.PERMISSION_DENIED:
        return 'Please allow location access to discover nearby users';
      case error.POSITION_UNAVAILABLE:
        return 'Location information is unavailable';
      case error.TIMEOUT:
        return 'Location request timed out';
      default:
        return 'An unknown error occurred while getting location';
    }
  }

  stopDiscovering() {
    this.discovering = false;
    
    if (this.watchId !== null) {
      navigator.geolocation.clearWatch(this.watchId);
      this.watchId = null;
    }
    
    if (this.discoveryInterval) {
      clearInterval(this.discoveryInterval);
      this.discoveryInterval = null;
    }

    // Clear user data
    this.undiscoveredUsers.clear();
    this.lastSeenTimes.clear();
  }

  getDiscoveredUsers(): LocationUser[] {
    return Array.from(this.undiscoveredUsers.values());
  }
}

export const locationDiscovery = new LocationDiscovery();