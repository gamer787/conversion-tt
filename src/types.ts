export interface User {
  id: string;
  username: string;
  name: string;
  bio: string;
  avatar: string;
  links: User[];
  brands: Brand[];
  posts: Post[];
  reels: Reel[];
}

export interface Brand {
  id: string;
  name: string;
  logo: string;
  verified: boolean;
}

export interface Post {
  id: string;
  userId: string;
  type: 'image' | 'video';
  content: string;
  caption: string;
  likes: number;
  comments: Comment[];
  createdAt: string;
}

export interface Reel {
  id: string;
  userId: string;
  videoUrl: string;
  caption: string;
  likes: number;
  comments: Comment[];
  createdAt: string;
}

export interface Comment {
  id: string;
  userId: string;
  content: string;
  createdAt: string;
}

export interface Message {
  id: string;
  senderId: string;
  receiverId: string;
  content: string;
  createdAt: string;
  read: boolean;
}

export interface Notification {
  id: string;
  userId: string;
  type: 'link_request' | 'link_accepted' | 'comment' | 'like' | 'mention';
  content: string;
  read: boolean;
  createdAt: string;
}