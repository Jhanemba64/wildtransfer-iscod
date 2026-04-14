// @ts-nocheck
import { describe, it, expect } from 'vitest';
import { cn, decodeJWT } from './globalUtils';

describe('cn', () => {
    it('should merge class names', () => {
        expect(cn('foo', 'bar')).toBe('foo bar');
    });

    it('should handle conditional classes', () => {
        expect(cn('base', false && 'hidden', 'visible')).toBe('base visible');
    });

    it('should deduplicate conflicting tailwind classes', () => {
        expect(cn('p-4', 'p-2')).toBe('p-2');
    });

    it('should handle undefined and null', () => {
        expect(cn('base', undefined, null, 'end')).toBe('base end');
    });

    it('should handle empty input', () => {
        expect(cn()).toBe('');
    });
});

describe('decodeJWT', () => {
    it('should decode a valid JWT payload', () => {
        // JWT with payload: { "email": "test@test.com", "role": "USER" }
        const payload = btoa(JSON.stringify({ email: 'test@test.com', role: 'USER' }));
        const token = `header.${payload}.signature`;
        const result = decodeJWT(token);
        expect(result).toEqual({ email: 'test@test.com', role: 'USER' });
    });

    it('should return null for invalid token', () => {
        expect(decodeJWT('invalid')).toBeNull();
    });

    it('should return null for empty string', () => {
        expect(decodeJWT('')).toBeNull();
    });
});
