import express from 'express';
import cors from 'cors';
import { PrismaClient } from '@prisma/client';
import authRoutes from './routes/authRoutes';
import topicRoutes from './routes/topicRoutes';
import contentRoutes from './routes/contentRoutes';
import errorHandler from './middleware/errorHandler';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Initialize express app
const app = express();

// Create and export Prisma client instance
export const prisma = new PrismaClient();

// Simple array of allowed origins
const allowedOrigins = [
  process.env.FRONTEND_URL || 'http://localhost:5173',
  'http://localhost:3000',
  'http://localhost:5001',
  'http://127.0.0.1:5173',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:5001',
];

// Middlewares
app.use(express.json());

// Simple CORS setup for development
if (process.env.NODE_ENV === 'development') {
  app.use(cors({
    origin: true, // Allow any origin in development
    credentials: true,
  }));
} else {
  // Production CORS setup
  app.use(cors({
    origin: allowedOrigins,
    credentials: true,
  }));
}

// Log requests in development
if (process.env.NODE_ENV !== 'production') {
  app.use((req, res, next) => {
    console.log(`${req.method} ${req.url}`);
    next();
  });
}

// Welcome message at root
app.get('/', (req, res) => {
  res.status(200).json({ 
    message: 'Welcome to the Notes API - a WordPress-like publishing platform',
    info: 'Public content can be accessed without authentication while admin features require login',
    endpoints: {
      auth: '/api/auth',
      topics: '/api/topics',
      content: '/api/content'
    }
  });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/topics', topicRoutes);
app.use('/api/content', contentRoutes);

// Health check route
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Error handling middleware
app.use(errorHandler);

export default app;