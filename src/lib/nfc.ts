import { supabase } from './supabase';

export interface NFCUser {
  id: string;
  username: string;
  display_name: string;
  avatar_url: string | null;
  account_type: 'personal' | 'business';
  last_seen: Date;
}

class NFCScanner {
  private scanning: boolean = false;
  private onUserDiscovered: ((user: NFCUser) => void) | null = null;
  private onError: ((error: string) => void) | null = null;
  private abortController: AbortController | null = null;

  async isAvailable(): Promise<boolean> {
    try {
      if (!('NDEFReader' in window)) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  setOnUserDiscovered(callback: (user: NFCUser) => void) {
    this.onUserDiscovered = callback;
  }

  setOnError(callback: (error: string) => void) {
    this.onError = callback;
  }

  async startScanning() {
    if (this.scanning) {
      return;
    }

    try {
      if (!await this.isAvailable()) {
        // Silently fail if NFC is not available
        return;
      }

      this.scanning = true;
      this.abortController = new AbortController();

      const ndef = new (window as any).NDEFReader();
      await ndef.scan({ signal: this.abortController.signal });

      ndef.addEventListener("reading", async ({ serialNumber, message }: any) => {
        try {
          // Get current user
          const { data: { user } } = await supabase.auth.getUser();
          if (!user) return;

          // Register this NFC tag in our system
          await supabase
            .from('discovered_users')
            .upsert({
              discoverer_id: user.id,
              discovered_id: user.id,
              bluetooth_id: `nfc:${serialNumber}`, // Use the same table with a prefix
              last_seen: new Date().toISOString()
            });

          // Try to decode user info from NFC tag
          for (const record of message.records) {
            if (record.recordType === "text") {
              const textDecoder = new TextDecoder();
              const text = textDecoder.decode(record.data);
              
              try {
                const userData = JSON.parse(text);
                if (userData.userId) {
                  // Get user profile from Supabase
                  const { data: profile } = await supabase
                    .from('profiles')
                    .select('*')
                    .eq('id', userData.userId)
                    .single();

                  if (profile && this.onUserDiscovered) {
                    this.onUserDiscovered({
                      id: profile.id,
                      username: profile.username,
                      display_name: profile.display_name,
                      avatar_url: profile.avatar_url,
                      account_type: profile.account_type,
                      last_seen: new Date()
                    });
                  }
                }
              } catch (e) {
                console.error('Error parsing NFC data:', e);
              }
            }
          }
        } catch (error) {
          console.error('Error processing NFC tag:', error);
        }
      });

      ndef.addEventListener("error", (error: Error) => {
        if (this.onError) {
          this.onError(error.message);
        }
      });

    } catch (error) {
      this.scanning = false;
      const errorMessage = error instanceof Error ? error.message : 'Failed to start NFC scanning';
      if (this.onError) {
        this.onError(errorMessage);
      }
      throw error;
    }
  }

  stopScanning() {
    this.scanning = false;
    if (this.abortController) {
      this.abortController.abort();
      this.abortController = null;
    }
  }

  async writeUserData(userId: string) {
    try {
      const ndef = new (window as any).NDEFReader();
      await ndef.write({
        records: [{
          recordType: "text",
          data: JSON.stringify({ userId })
        }]
      });
      return true;
    } catch (error) {
      console.error('Error writing NFC tag:', error);
      return false;
    }
  }
}

export const nfcScanner = new NFCScanner();