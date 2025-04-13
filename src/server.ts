import app from './app';
import dotenv from 'dotenv';
import { prisma } from './app';

dotenv.config();

const PORT = process.env.PORT || 5000;

// Start the server
const server = app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
});

// Graceful shutdown handling
const gracefulShutdown = async (signal: string) => {
  console.log(`Received ${signal}, starting graceful shutdown`);
  
  // Close the server first to stop accepting new connections
  server.close(() => {
    console.log('HTTP server closed');
    
    // Close database connections
    prisma.$disconnect()
      .then(() => {
        console.log('Database connections closed');
        process.exit(0);
      })
      .catch((err) => {
        console.error('Error during database disconnection', err);
        process.exit(1);
      });
  });
  
  // Add timeout to force exit if graceful shutdown takes too long
  setTimeout(() => {
    console.error('Forcing shutdown after timeout');
    process.exit(1);
  }, 30000); // 30 seconds timeout
};

// Listen for termination signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));