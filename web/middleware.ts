import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

// Phase 1: presence check only. Full session-cookie verification via
// firebase-admin (adminAuth.verifySessionCookie) to be wired once the
// login page sets an httpOnly session cookie (Phase 1 follow-up).
export function middleware(req: NextRequest) {
  const session = req.cookies.get("__session");
  const isDashboard = req.nextUrl.pathname.startsWith("/dashboard");

  if (isDashboard && !session) {
    return NextResponse.redirect(new URL("/login", req.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/dashboard/:path*"],
};
