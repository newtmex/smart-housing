import { ReactNode } from "react";
import Image from "next/image";

const SlideWrapper = ({
  children,
  title,
  description,
  imageScr,
  image,
  ...props
}: {
  imageScr: string;
  children?: ReactNode;
  title?: ReactNode;
  description?: ReactNode;
  image?: ReactNode;
}) => (
  <div className="onboarding-side-by-side d-flex" {...props}>
    <div className="onboarding-media flex-grow-2">
      {image ? image : <Image alt="" src={"/" + imageScr} width={200} height={200} />}
    </div>
    <div className="onboarding-content with-gradient flex-grow-1" style={{ width: "100%", overflow: "scroll" }}>
      {title && <h4 className="onboarding-title">{title}</h4>}
      {description && (
        <div style={{ display: "flex", overflow: "scroll", flexDirection: "column" }} className="onboarding-text">
          {description}
        </div>
      )}

      {children}
    </div>
  </div>
);

export default SlideWrapper;
