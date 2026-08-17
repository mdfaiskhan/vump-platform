import { describe, it, expect, vi } from 'vitest';
import type { APIGatewayProxyEvent } from 'aws-lambda';
import { createRouter, routeKey, type RouteTable } from './router.js';

function event(method: string, resource: string): APIGatewayProxyEvent {
  return { httpMethod: method, resource, headers: {} } as unknown as APIGatewayProxyEvent;
}

describe('the router', () => {
  it('keys on the matched resource TEMPLATE, not the concrete path', () => {
    expect(routeKey('get', '/v1/tasks/{taskId}')).toBe('GET /v1/tasks/{taskId}');
  });

  it('dispatches to the handler registered for a method and template', async () => {
    const handler = vi.fn().mockResolvedValue({ statusCode: 200, body: '{}' });
    const routes: RouteTable = { [routeKey('GET', '/v1/projects')]: handler };

    await createRouter('projects', routes)(event('GET', '/v1/projects'));

    expect(handler).toHaveBeenCalledOnce();
  });

  it('distinguishes methods on the same template', async () => {
    const get = vi.fn().mockResolvedValue({ statusCode: 200, body: '{}' });
    const post = vi.fn().mockResolvedValue({ statusCode: 201, body: '{}' });
    const routes: RouteTable = {
      [routeKey('GET', '/v1/projects')]: get,
      [routeKey('POST', '/v1/projects')]: post,
    };

    await createRouter('projects', routes)(event('POST', '/v1/projects'));

    expect(post).toHaveBeenCalledOnce();
    expect(get).not.toHaveBeenCalled();
  });

  it('answers an unregistered route with a 404 envelope', async () => {
    const response = await createRouter('projects', {})(event('GET', '/v1/nope'));

    expect(response.statusCode).toBe(404);
    expect(JSON.parse(response.body)).toEqual({
      data: null,
      error: { code: 'RESOURCE_NOT_FOUND', message: 'No handler is registered for GET /v1/nope.' },
    });
  });
});
