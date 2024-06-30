import csv
with (
    open('Qwerty to Dvorak.csv', newline='', encoding='utf-8_sig') as file1,
    open('ienne\\ienneLayout.csv', newline='', encoding='utf-8_sig') as file2,
    open('qwertyIenne.csv', 'w', newline='', encoding='utf-8_sig') as out_file
):
    csv1 = csv.reader(file1)
    csv2 = csv.reader(file2)
    out_csv = csv.writer(out_file)
    dict1 = dict(reversed(row) for row in csv1)
    for row in csv2:
        key = dict1[row[0]] if row[0] in dict1 else row[0]
        out_csv.writerow([key] + row[1:])