import { callAI } from './call-ai.js';
import { presetById } from '../lib/constants.js';

export async function generateRaceConditions(event) {
  const p = presetById(event.presetId);
  const prompt = `You are an expert endurance sports analyst. Given the following race details, provide a brief conditions analysis. Be specific and actionable.

Race: ${event.name}
Type: ${p.label}
Location: ${event.location || 'Unknown'}
Date: ${event.date || 'Unknown'}

Respond with ONLY valid JSON in this exact format (no markdown, no code fences):
{
  "summary": "2-4 word summary like 'Hot, hilly, coastal'",
  "terrain": "1-2 sentences about the course terrain and elevation profile",
  "elevation": "Estimated elevation gain like '~800ft total gain' or 'Flat' if unknown say 'Check course map'",
  "climate": "1-2 sentences about expected weather conditions for this location and time of year",
  "tips": ["tip 1", "tip 2", "tip 3"]
}

For well-known races (Boston Marathon, Ironman Kona, etc.) include course-specific details. For lesser-known races, provide general analysis based on the location and time of year. Always provide 3-5 practical tips.`;

  try {
    const res = await callAI({
      system: 'You are a sports analyst. Respond with valid JSON only. No markdown code fences.',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 512,
    });
    const text = res.content?.[0]?.text || '';
    const cleaned = text.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();
    const parsed = JSON.parse(cleaned);
    return { ...parsed, generatedAt: new Date().toISOString() };
  } catch (err) {
    console.error('AI conditions generation failed:', err);
    return null;
  }
}
