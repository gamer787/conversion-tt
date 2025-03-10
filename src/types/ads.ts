export interface PriceTier {
  id: string;
  duration_hours: number;
  radius_km: number;
  price: number;
}

export interface Content {
  id: string;
  type: 'vibe' | 'banger';
  content_url: string;
  caption: string;
  created_at: string;
}

export interface AdCampaign {
  id: string;
  user_id: string;
  content_id: string;
  duration_hours: number;
  radius_km: number;
  price: number;
  views: number;
  status: 'pending' | 'active' | 'completed';
  start_time: string | null;
  end_time: string | null;
  created_at: string;
  likes_count: number;
  comments_count: number;
  content?: {
    id: string;
    type: 'vibe' | 'banger';
    content_url: string;
    caption: string;
  };
  user?: {
    username: string;
    display_name: string;
    avatar_url: string | null;
    account_type: string;
  };
}