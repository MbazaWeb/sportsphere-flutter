// vps/ecosystem.config.cjs
// PM2 process manager config for Playify VPS
// Usage: pm2 start vps/ecosystem.config.cjs

module.exports = {
  apps: [
    {
      name:       'playify-api',
      script:     'bun',
      args:       'run src/index.ts',
      cwd:        '/var/playify/app/vps/api',
      instances:  1,              // scale to 'max' when CPX31+
      exec_mode:  'fork',         // use 'cluster' at CPX41 with max instances
      env: {
        NODE_ENV: 'production',
        PORT:     3000,
      },
      env_file:   '/var/playify/app/vps/api/.env',
      watch:      false,
      max_memory_restart: '512M',
      restart_delay:      3000,
      log_date_format:    'YYYY-MM-DD HH:mm:ss',
      error_file:         '/var/playify/logs/api-error.log',
      out_file:           '/var/playify/logs/api-out.log',
      merge_logs:         true,
    },
    {
      name:   'playify-soketi',
      script: 'soketi',
      args:   'start --config /etc/playify/soketi.json',
      instances: 1,
      watch:  false,
      max_memory_restart: '256M',
      error_file: '/var/playify/logs/soketi-error.log',
      out_file:   '/var/playify/logs/soketi-out.log',
    },
  ],
}
