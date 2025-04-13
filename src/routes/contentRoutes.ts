import express , { Request, Response } from 'express';
import { 
  getSubtopicContent, 
  updateSubtopicContent, 
  deleteSubtopic 
} from '../controllers/contentController';
import { protect, admin } from '../middleware/auth';

const router = express.Router();

// Route for getting content by slug
router.get('/:topicSlug/:subtopicSlug', getSubtopicContent);

// Routes for administrative actions (by ID)
router.put('/subtopics/:subtopicId', protect, admin, updateSubtopicContent);
router.delete('/subtopics/:subtopicId', protect, admin, deleteSubtopic);

export default router;