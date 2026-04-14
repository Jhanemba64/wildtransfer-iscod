import { calculateStoragePercentage, formatFileSize } from './storageUtils';

describe('calculateStoragePercentage', () => {
    it('should return 0 for 0 bytes', () => {
        expect(calculateStoragePercentage(0)).toBe(0);
    });

    it('should return 100 for max storage (20MB)', () => {
        expect(calculateStoragePercentage(20971520)).toBe(100);
    });

    it('should return 50 for half storage', () => {
        expect(calculateStoragePercentage(10485760)).toBe(50);
    });

    it('should clamp negative values to 0', () => {
        expect(calculateStoragePercentage(-100)).toBe(0);
    });

    it('should clamp values above max to 100', () => {
        expect(calculateStoragePercentage(30000000)).toBe(100);
    });

    it('should round to 2 decimal places', () => {
        const result = calculateStoragePercentage(1000000);
        expect(result).toBe(Math.round((1000000 / 20971520) * 100 * 100) / 100);
    });
});

describe('formatFileSize', () => {
    it('should return "0 Bytes" for 0', () => {
        expect(formatFileSize(0)).toBe('0 Bytes');
    });

    it('should format bytes', () => {
        expect(formatFileSize(500)).toBe('500.00 Bytes');
    });

    it('should format kilobytes', () => {
        expect(formatFileSize(1024)).toBe('1.00 KB');
    });

    it('should format megabytes', () => {
        expect(formatFileSize(1048576)).toBe('1.00 MB');
    });

    it('should format gigabytes', () => {
        expect(formatFileSize(1073741824)).toBe('1.00 GB');
    });

    it('should format with decimals', () => {
        expect(formatFileSize(1536)).toBe('1.50 KB');
    });
});
