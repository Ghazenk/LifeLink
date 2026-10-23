import {HttpError} from './http.ts';

// Self-declaration / staff verification, not independent identity or age proof.
// Never log the input or retain rejected registration attempts.
export function requireAgeEligibility(input: Record<string, unknown>): void {
  if (input.age_13_or_older !== true) {
    throw new HttpError(400, 'Age 13 or older must be verified before account creation.');
  }
}
