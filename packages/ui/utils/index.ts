import { numberToPaddedHex } from "@multiversx/sdk-core/out/utils.codec";

export * from "./sdkDappUtils";

export const APP_NAME = "Smart Housing";

export class RefIdData {
  static spliter = "q";
  static refIDLength = 8;

  refID?: string;

  constructor(
    public address: string,
    userID: number,
  ) {
    this.setRefID(userID);
    this.getUserID();
  }

  private setRefID(userID: number) {
    if (userID > 0) {
      let refIDhex = numberToPaddedHex(userID);
      // 2^32 - 1 can fit into 8 chars of hex, so we pad with address and spliter
      if (refIDhex.length < RefIdData.refIDLength) {
        refIDhex = `${refIDhex}${RefIdData.spliter}`;

        const extraPaddingLen = refIDhex.length - RefIdData.refIDLength;
        if (extraPaddingLen < 0) {
          const addressPadding = this.address.slice(extraPaddingLen);
          refIDhex = `${refIDhex}${addressPadding}`;
        }
      }

      this.refID = refIDhex;
    }
  }

  getUserID(): number | null {
    if (!this.refID) {
      return null;
    }

    return RefIdData.getID(this.refID);
  }

  static getID(refID: string): number {
    const idHex = refID.split(new RegExp(`(?<=[0-9a-f])${RefIdData.spliter}`))[0];

    return hexToNumber(idHex);
  }
}

function hexToNumber(hex: string): number {
  return parseInt(hex, 16);
}

export const getUnixTimestampWithAddedSeconds = (addedSeconds: number) => {
  return new Date().setSeconds(new Date().getSeconds() + addedSeconds) / 1000;
};

export const getUnixTimestamp = () => {
  return Date.now() / 1000;
};
