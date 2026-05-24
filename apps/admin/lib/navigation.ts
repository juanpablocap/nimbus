export interface NavItem { label: string; href: string; icon: string; }
export interface NavSection { title: string; items: NavItem[]; }

export const navigation: NavSection[] = [
  { title: "Overview", items: [
    { label: "Dashboard", href: "/", icon: "grid" },
  ]},
  { title: "Operations", items: [
    { label: "Residents", href: "/residents", icon: "users" },
    { label: "Properties", href: "/properties", icon: "building" },
    { label: "Visits", href: "/visits", icon: "calendar-check" },
    { label: "Access Logs", href: "/access-logs", icon: "shield-check" },
  ]},
  { title: "Community", items: [
    { label: "News", href: "/news", icon: "megaphone" },
  ]},
];
