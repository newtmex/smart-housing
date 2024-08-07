import { getUnixTimestamp, getUnixTimestampWithAddedSeconds } from "~~/utils";

export type SessionKeyData = { key: "userRefBy"; data: string };

export const setItem = ({ key, data }: SessionKeyData, secondsToExipre = 3600) => {
  const expires = getUnixTimestampWithAddedSeconds(secondsToExipre);
  sessionStorage.setItem(
    String(key),
    JSON.stringify({
      expires,
      data,
    }),
  );
};

//TODO: set the return type based on key type
export const getItem = <Data = SessionKeyData["data"]>(key: SessionKeyData["key"]): Data | null => {
  const item = sessionStorage.getItem(String(key));
  if (!item) {
    return null;
  }

  const deserializedItem = JSON.parse(item);
  if (!deserializedItem) {
    return null;
  }

  if (!deserializedItem.hasOwnProperty("expires") || !deserializedItem.hasOwnProperty("data")) {
    return null;
  }

  const expired = getUnixTimestamp() >= deserializedItem.expires;
  if (expired) {
    sessionStorage.removeItem(String(key));
    return null;
  }

  return deserializedItem.data;
};

export const removeItem = <Key extends SessionKeyData["key"]>(key: Key) => sessionStorage.removeItem(String(key));

export const clearSession = () => {
  // Preserve refID
  const refID = getItem<string>("userRefBy");

  sessionStorage.clear();

  refID && setItem({ key: "userRefBy", data: refID });
};
