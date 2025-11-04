import Ajv from "https://esm.sh/ajv@8.12.0";
import addFormats from "https://esm.sh/ajv-formats@2.1.1";

export const ajv = new Ajv({
  strict: true,
  allErrors: true,
  removeAdditional: false,
  useDefaults: false,
  coerceTypes: false,
});
addFormats(ajv, ["email", "uri", "uuid"]);
