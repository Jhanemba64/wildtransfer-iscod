import { describe, it, expect } from 'vitest';
import { getFileTypeInfo, formatFileSize, defaultAcceptedFileTypes } from './fileUtils';

describe('getFileTypeInfo', () => {
    it('should detect image files', () => {
        const result = getFileTypeInfo('photo.jpg');
        expect(result.isImage).toBe(true);
        expect(result.isVideo).toBe(false);
        expect(result.isPdf).toBe(false);
    });

    it('should detect video files', () => {
        const result = getFileTypeInfo('video.mp4');
        expect(result.isVideo).toBe(true);
        expect(result.isImage).toBe(false);
        expect(result.isPdf).toBe(false);
    });

    it('should detect PDF files', () => {
        const result = getFileTypeInfo('document.pdf');
        expect(result.isPdf).toBe(true);
        expect(result.isImage).toBe(false);
        expect(result.isVideo).toBe(false);
    });

    it('should handle uppercase extensions', () => {
        const result = getFileTypeInfo('photo.PNG');
        expect(result.isImage).toBe(true);
    });

    it('should return default for unknown extensions', () => {
        const result = getFileTypeInfo('file.xyz');
        expect(result.isImage).toBe(false);
        expect(result.isVideo).toBe(false);
        expect(result.isPdf).toBe(false);
    });

    it('should detect audio files', () => {
        const result = getFileTypeInfo('song.mp3');
        expect(result.emoji).toBe('🎵');
    });

    it('should detect spreadsheet files', () => {
        const result = getFileTypeInfo('data.xlsx');
        expect(result.emoji).toBe('📊');
    });

    it('should detect code files', () => {
        const result = getFileTypeInfo('app.tsx');
        expect(result.emoji).toBe('💻');
    });

    it('should detect archive files', () => {
        const result = getFileTypeInfo('backup.zip');
        expect(result.emoji).toBe('📦');
    });

    it('should detect document files', () => {
        const result = getFileTypeInfo('readme.docx');
        expect(result.emoji).toBe('📝');
    });

    it('should handle files without extension', () => {
        const result = getFileTypeInfo('Makefile');
        expect(result.isImage).toBe(false);
        expect(result.isVideo).toBe(false);
        expect(result.isPdf).toBe(false);
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

describe('defaultAcceptedFileTypes', () => {
    it('should include PDF', () => {
        expect(defaultAcceptedFileTypes['application/pdf']).toContain('.pdf');
    });

    it('should include images', () => {
        expect(defaultAcceptedFileTypes['image/*']).toEqual(
            expect.arrayContaining(['.png', '.jpg', '.jpeg']),
        );
    });

    it('should include video', () => {
        expect(defaultAcceptedFileTypes['video/*']).toEqual(
            expect.arrayContaining(['.mp4', '.mov']),
        );
    });
});
