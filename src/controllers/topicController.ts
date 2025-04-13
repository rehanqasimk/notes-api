import { Request, Response } from 'express';
import { prisma } from '../app';

// Get all topics with subtopics
export const getAllTopics = async (req: Request, res: Response): Promise<void> => {
  try {
    const topics = await prisma.topic.findMany({
      include: {
        subtopics: {
          select: {
            id: true,
            title: true,
            slug: true,
            order: true,
          },
          orderBy: {
            order: 'asc',
          },
        },
      },
      orderBy: {
        order: 'asc',
      },
    });

    res.json(topics);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// Create a new topic
export const createTopic = async (req: Request, res: Response): Promise<void> => {
  try {
    const { title, slug } = req.body;

    // Check if slug is already used
    const existingTopic = await prisma.topic.findUnique({
      where: { slug },
    });

    if (existingTopic) {
      res.status(400).json({ message: 'Topic with this slug already exists' });
      return;
    }

    // Get highest order
    const highestOrder = await prisma.topic.findFirst({
      orderBy: { order: 'desc' },
      select: { order: true },
    });
    
    const newOrder = highestOrder ? highestOrder.order + 1 : 0;

    const topic = await prisma.topic.create({
      data: {
        title,
        slug,
        order: newOrder,
      },
    });

    res.status(201).json(topic);
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};

// Create a subtopic within a topic
export const createSubtopic = async (req: Request, res: Response): Promise<void> => {
  try {
    const { topicId } = req.params;
    const { title, slug, content } = req.body;

    // Check if topic exists
    const topic = await prisma.topic.findUnique({
      where: { id: parseInt(topicId) },
      include: { subtopics: true },
    });

    if (!topic) {
      res.status(404).json({ message: 'Topic not found' });
      return;
    }

    // Check if slug is already used within this topic
    const existingSubtopic = topic.subtopics.find((st: { slug: string }) => st.slug === slug);
    if (existingSubtopic) {
      res.status(400).json({ message: 'Subtopic with this slug already exists in this topic' });
      return;
    }

    // Get highest order for this topic
    const highestOrder = await prisma.subtopic.findFirst({
      where: { topicId: parseInt(topicId) },
      orderBy: { order: 'desc' },
      select: { order: true },
    });
    
    const newOrder = highestOrder ? highestOrder.order + 1 : 0;

    // Create subtopic with content
    const subtopic = await prisma.subtopic.create({
      data: {
        title,
        slug,
        order: newOrder,
        topic: { connect: { id: parseInt(topicId) } },
        content: content ? { create: { html: content } } : undefined,
      },
      include: { content: true },
    });

    res.status(201).json(subtopic);
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};

// Update a topic
export const updateTopic = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { title, slug, order } = req.body;
    
    // Make sure slug is unique if provided
    if (slug) {
      const existingTopic = await prisma.topic.findFirst({
        where: { 
          slug,
          id: { not: parseInt(id) }
        },
      });
      
      if (existingTopic) {
        res.status(400).json({ message: 'Topic with this slug already exists' });
        return;
      }
    }
    
    const topic = await prisma.topic.update({
      where: { id: parseInt(id) },
      data: {
        title: title !== undefined ? title : undefined,
        slug: slug !== undefined ? slug : undefined,
        order: order !== undefined ? order : undefined,
      },
    });
    
    res.json(topic);
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};

// Delete a topic
export const deleteTopic = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    
    await prisma.topic.delete({
      where: { id: parseInt(id) },
    });
    
    res.json({ message: 'Topic deleted successfully' });
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};

// Get a specific subtopic by ID
export const getSubtopicById = async (req: Request, res: Response): Promise<void> => {
  try {
    const { topicId, subtopicId } = req.params;
    
    // Log the parameters to debug
    console.log('Getting subtopic with params:', { topicId, subtopicId });
    
    // Check if we're receiving numeric IDs or slugs
    const isNumeric = (value: string) => /^\d+$/.test(value);
    
    let subtopic;
    
    if (isNumeric(topicId) && isNumeric(subtopicId)) {
      // If both are numeric, treat as IDs
      subtopic = await prisma.subtopic.findFirst({
        where: { 
          id: parseInt(subtopicId),
          topicId: parseInt(topicId)
        },
        include: { content: true },
      });
    } else {
      // If not numeric, treat as slugs
      const topic = await prisma.topic.findUnique({
        where: { slug: topicId }, // topicId is actually a slug here
      });
      
      if (!topic) {
        res.status(404).json({ message: 'Topic not found' });
        return;
      }
      
      subtopic = await prisma.subtopic.findFirst({
        where: {
          slug: subtopicId, // subtopicId is actually a slug here
          topicId: topic.id
        },
        include: { content: true },
      });
    }

    if (!subtopic) {
      res.status(404).json({ message: 'Subtopic not found' });
      return;
    }

    res.json(subtopic);
  } catch (error: any) {
    console.error('Error in getSubtopicById:', error);
    res.status(400).json({ message: error.message });
  }
};