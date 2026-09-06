module.exports = {
  // PM2 process manager config for Playify VPS API.
  // Invokes `bun run src/index.ts` from the vps/api directory so that Bun
  // recognises `export default { port, hostname, fetch, websocket }` as a
  // server entry point. (Using `interpreter` + relative `script` from the
  // repo root does NOT trigger the auto-serve — Bun only starts the server
  // when the file is the main entry point, not when require()'d by PM2's
  // ProcessContainerForkBun wrapper.)
  apps: [{
    name: 'playify-api',
    script: '/home/david/.bun/bin/bun',
    args: 'run /var/playify/app/vps/api/src/index.ts',
    cwd: '/var/playify/app/vps/api',
    env_file: '/var/playify/app/vps/api/.env',
    watch: false,
    max_memory_restart: '512M',
  }]
}
