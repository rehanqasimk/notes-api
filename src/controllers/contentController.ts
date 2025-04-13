import { Request, Response } from 'express';
import { prisma } from '../app';

// Get content for a specific subtopic
export const getSubtopicContent = async (req: Request, res: Response): Promise<void> => {
  try {
    const { topicSlug, subtopicSlug } = req.params;
    
    console.log('Getting content for topic/subtopic:', { topicSlug, subtopicSlug });

    const topic = await prisma.topic.findUnique({
      where: { slug: topicSlug },
    });

    if (!topic) {
      res.status(404).json({ message: 'Topic not found' });
      return;
    }

    const subtopic = await prisma.subtopic.findFirst({
      where: {
        topicId: topic.id,
        slug: subtopicSlug,
      },
      include: { content: true },
    });

    if (!subtopic) {
      res.status(404).json({ message: 'Subtopic not found' });
      return;
    }

    // For public facing routes, we want a clean response with just what's needed
    const responseData = {
      id: subtopic.id,
      title: subtopic.title,
      slug: subtopic.slug,
      topicId: subtopic.topicId,
      topicTitle: topic.title,
      topicSlug: topic.slug,
      content: subtopic.content ? subtopic.content.html : null,
      order: subtopic.order,
    };

    res.json(responseData);
  } catch (error: any) {
    console.error('Error in getSubtopicContent:', error);
    res.status(500).json({ message: error.message });
  }
};

// Update content for a specific subtopic
export const updateSubtopicContent = async (req: Request, res: Response): Promise<void> => {
  try {
    const { subtopicId } = req.params;
    const { html } = req.body;

    console.log(`Updating content for subtopic ID ${subtopicId}`);
    console.log('New HTML content length:', html?.length || 0);

    const subtopic = await prisma.subtopic.findUnique({
      where: { id: parseInt(subtopicId) },
      include: { content: true },
    });

    if (!subtopic) {
      res.status(404).json({ message: 'Subtopic not found' });
      return;
    }

    let updatedContent;

    if (subtopic.content) {
      console.log(`Updating existing content for subtopic ID ${subtopicId}`);
      updatedContent = await prisma.content.update({
        where: { subtopicId: parseInt(subtopicId) },
        data: { html },
      });
    } else {
      console.log(`Creating new content for subtopic ID ${subtopicId}`);
      updatedContent = await prisma.content.create({
        data: {
          html,
          subtopic: { connect: { id: parseInt(subtopicId) } },
        },
      });
    }

    console.log('Content updated successfully');

    // Return a response that matches the expected Subtopic interface format
    res.json({
      id: subtopic.id,
      title: subtopic.title,
      slug: subtopic.slug,
      topicId: subtopic.topicId,
      order: subtopic.order,
      content: updatedContent.html,
    });
    return;
  } catch (error: any) {
    console.error('Error in updateSubtopicContent:', error);
    res.status(400).json({ message: error.message });
    return;
  }
};

// Delete content for a specific subtopic
export const deleteSubtopic = async (req: Request, res: Response): Promise<void> => {
  try {
    const { subtopicId } = req.params;

    await prisma.subtopic.delete({
      where: { id: parseInt(subtopicId) },
    });

    res.json({ message: 'Subtopic and its content deleted successfully' });
    return;
  } catch (error: any) {
    res.status(400).json({ message: error.message });
    return;
  }
};