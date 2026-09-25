export function getDomain(): string {
    if (process.env.APP_URL) return process.env.APP_URL;

    const env = process.env.NODE_ENV;
    
    switch (env) {
        case 'production':
            return 'https://wildtransfer.cloud';
        case 'staging':
            return 'https://staging.wildtransfer.cloud';
        case 'development':
        default:
            return 'http://localhost:7007';
    }
}