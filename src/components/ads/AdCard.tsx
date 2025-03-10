import React from 'react';
import { Heart, MessageCircle, StopCircle, Eye, MapPin, Clock } from 'lucide-react';
import { Link } from 'react-router-dom';
import { format } from 'date-fns';
import type { AdCampaign } from '../../types/ads';

interface AdCardProps {
  campaign: AdCampaign;
  onLike: (postId: string) => void;
  onComment: (postId: string) => void;
  onStop: (campaignId: string) => void;
  likedPosts: Set<string>;
}

export function AdCard({ campaign, onLike, onComment, onStop, likedPosts }: AdCardProps) {
  return (
    <div className="bg-gray-900 p-4 rounded-lg">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center space-x-4">
          <div className="w-16 h-16 bg-gray-800 rounded-lg overflow-hidden">
            {campaign.content?.type === 'vibe' ? (
              <img
                src={campaign.content.content_url}
                alt="Campaign content"
                className="w-full h-full object-cover"
              />
            ) : (
              <video
                src={campaign.content?.content_url}
                className="w-full h-full object-cover"
              />
            )}
          </div>
          <div>
            <h3 className="font-semibold">Campaign #{campaign.id.slice(0, 8)}</h3>
            {campaign.user && (
              <Link 
                to={`/profile/${campaign.user.username}`}
                className="text-sm text-gray-400 hover:text-cyan-400 transition-colors"
              >
                {campaign.user.display_name}
              </Link>
            )}
            <div className="flex items-center text-sm text-gray-400 space-x-4 mt-1">
              <div className="flex items-center">
                <Clock className="w-4 h-4 mr-1" />
                {campaign.duration_hours}h
              </div>
              <div className="flex items-center">
                <MapPin className="w-4 h-4 mr-1" />
                {campaign.radius_km}km
              </div>
            </div>
          </div>
        </div>
        <div className="text-right">
          <div className="flex items-center text-cyan-400 mb-1">
            <Eye className="w-4 h-4 mr-1" />
            {campaign.views} views
          </div>
          <div className="text-sm text-gray-400">
            ₹{campaign.price}
          </div>
        </div>
      </div>

      {/* Post Actions */}
      <div className="flex items-center space-x-4 mt-4">
        <button
          onClick={() => onLike(campaign.content?.id || campaign.content_id)}
          className={`flex items-center space-x-1 transition-colors ${
            likedPosts.has(campaign.content?.id || campaign.content_id)
              ? 'text-pink-500'
              : 'text-gray-400 hover:text-pink-500'
          }`}
        >
          <Heart
            className={`w-6 h-6 ${likedPosts.has(campaign.content?.id || campaign.content_id) ? 'fill-current' : ''}`}
          />
          <span>{campaign.likes_count}</span>
        </button>
        <button 
          onClick={() => onComment(campaign.content?.id || campaign.content_id)}
          className="flex items-center space-x-1 text-gray-400 hover:text-purple-500 transition-colors"
        >
          <MessageCircle className="w-6 h-6" />
          <span>{campaign.comments_count}</span>
        </button>
        <button
          onClick={() => onStop(campaign.id)}
          className="flex items-center space-x-1 text-gray-400 hover:text-red-500 transition-colors"
        >
          <StopCircle className="w-6 h-6" />
          <span>Stop</span>
        </button>
      </div>

      {/* Progress bar */}
      <div className="h-2 bg-gray-800 rounded-full overflow-hidden mt-4">
        <div
          className="h-full bg-cyan-400"
          style={{
            width: `${Math.min(
              ((new Date().getTime() - new Date(campaign.start_time!).getTime()) /
              (new Date(campaign.end_time!).getTime() - new Date(campaign.start_time!).getTime())) * 100,
              100
            )}%`
          }}
        />
      </div>
    </div>
  );
}