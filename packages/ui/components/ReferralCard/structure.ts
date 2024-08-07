type ReferralIDUrlSegment = `?refID=${string}`;

export class ReferralIDStructure {
  static makeUrlSegment(refId: string): ReferralIDUrlSegment {
    return `?refID=${refId}`;
  }
}
