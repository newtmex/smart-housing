"use client";

import React from "react";
import Modal from "react-bootstrap/Modal";
import useSWR from "swr";

export type ModalType = null | React.ReactNode;

export const useModalToShow = () => {
  const { data, mutate } = useSWR<ModalType>("ui-modal-to-show", {
    fallbackData: null,
  });

  return {
    modalToShow: data || null,
    closeModal: () => mutate(null),
    openModal: (modal: Exclude<ModalType, null>) => {
      mutate(modal);
    },
  };
};

export default function Modals() {
  const { modalToShow, closeModal } = useModalToShow();

  return (
    <Modal
      keyboard={false}
      backdrop={"static"}
      autoFocus={true}
      show={!!modalToShow}
      onHide={closeModal}
      className="onboarding-modal animated"
      dialogClassName="modal-lg modal-centered text-center"
    >
      {modalToShow}
    </Modal>
  );
}
