import 'hono'
declare module 'hono' {
  interface ContextVariableMap {
    userId: string
    token: string
  }
}
