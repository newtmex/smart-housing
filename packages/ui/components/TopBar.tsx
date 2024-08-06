import LoggedUserInfo from "./LoggedUserInfo";

export default function TopBar() {
  return (
    <div className="top-bar color-scheme-transparent">
      <div className="top-menu-controls">
        <LoggedUserInfo location="topbar" />
      </div>
    </div>
  );
}
