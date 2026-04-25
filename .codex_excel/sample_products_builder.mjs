import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const outputPath = path.join(__dirname, "sample_products_for_testing.xlsx");

const products = [
  ["2900000000013", 1, "Basmati Rice 1kg", 145, "Fortune"],
  ["2900000000020", 2, "Toor Dal 1kg", 132, "Tata Sampann"],
  ["2900000000037", 3, "Moong Dal 1kg", 118, "Tata Sampann"],
  ["2900000000044", 4, "Sugar 1kg", 48, "Madhur"],
  ["2900000000051", 5, "Salt 1kg", 22, "Tata"],
  ["2900000000068", 6, "Sunflower Oil 1L", 168, "Fortune"],
  ["2900000000075", 7, "Mustard Oil 1L", 182, "Dhara"],
  ["2900000000082", 8, "Atta 5kg", 265, "Aashirvaad"],
  ["2900000000099", 9, "Besan 500g", 54, "Pillsbury"],
  ["2900000000105", 10, "Poha 1kg", 62, "24 Mantra"],
  ["2900000000112", 11, "Tea 500g", 210, "Brooke Bond"],
  ["2900000000129", 12, "Coffee 100g", 145, "Nescafe"],
  ["2900000000136", 13, "Milk Biscuit 300g", 35, "Britannia"],
  ["2900000000143", 14, "Marie Biscuit 250g", 32, "Parle"],
  ["2900000000150", 15, "Noodles Pack", 18, "Maggi"],
  ["2900000000167", 16, "Tomato Ketchup 500g", 95, "Kissan"],
  ["2900000000174", 17, "Chilli Powder 200g", 68, "Everest"],
  ["2900000000181", 18, "Turmeric Powder 200g", 58, "MDH"],
  ["2900000000198", 19, "Bath Soap Pack", 122, "Lux"],
  ["2900000000204", 20, "Detergent Powder 1kg", 110, "Surf Excel"],
];

const workbook = Workbook.create();
const sheet = workbook.worksheets.add("Products");

sheet.getRange("A1:E1").values = [[
  "Barcode Number",
  "Product ID",
  "Product Name",
  "Price",
  "Brand",
]];

sheet.getRange(`A2:E${products.length + 1}`).values = products;

await fs.mkdir(__dirname, { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);

console.log(outputPath);
