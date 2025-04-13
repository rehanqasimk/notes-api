import express from 'express';
import { 
  getAllTopics, 
  createTopic, 
  createSubtopic, 
  updateTopic, 
  deleteTopic, 
  getSubtopicById 
} from '../controllers/topicController';
import { protect, admin } from '../middleware/auth';

const router = express.Router();

// Public routes (no authentication required)
router.get('/', getAllTopics);
router.get('/:topicId/subtopics/:subtopicId', getSubtopicById);

// Admin-only routes (require authentication)
router.post('/', protect, admin, createTopic);
router.post('/:topicId/subtopics', protect, admin, createSubtopic);
router.put('/:id', protect, admin, updateTopic);
router.delete('/:id', protect, admin, deleteTopic);

export default router;