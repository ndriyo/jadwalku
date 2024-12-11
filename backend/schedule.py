from pulp import LpProblem, LpMaximize, LpVariable, lpSum, LpStatus
import datetime
import json

# -----------------------------------------------------
# Data Input
# -----------------------------------------------------
with open('backend/slot.json', 'r') as file:
    AvailableSlot = json.load(file)
with open('backend/preferences.json', 'r') as file:
    StudentPreferences = json.load(file)

# -----------------------------------------------------
# Membuat Model ILP
# -----------------------------------------------------
model = LpProblem("Scheduling_Problem", LpMaximize)

students = list(StudentPreferences.keys())
days = list(AvailableSlot.keys())
batches = list(AvailableSlot["1"].keys())  # Assumes the structure is the same for each day
slot_count = len(AvailableSlot["1"]["1"])    # 5 slots per batch, using the third slot as reference

# Hitung timestamp paling awal
earliest_time = min(datetime.datetime.fromisoformat(StudentPreferences[s]["timestamp"]) for s in students)

# Waktu submit -> timestamp_weight
timestamp_weights = {}
for s in students:
    submit_time = datetime.datetime.fromisoformat(StudentPreferences[s]["timestamp"])
    hour_diff = (submit_time - earliest_time).total_seconds() / 3600.0
    timestamp_weight = 1/(1+hour_diff)
    timestamp_weights[s] = timestamp_weight

# Variabel keputusan: x_(s,d,b,sl)
# Karena preferensi hanya (d,b), maka untuk setiap preferensi kita buat variabel untuk kelima slot
x = {}
for s in students:
    for (d,b) in StudentPreferences[s]["preferences"]:
        for sl in range(slot_count):
            x[(s,d,b,sl)] = LpVariable(f"x_{s}_{d}_{b}_{sl}", cat="Binary")

# Bobot: final_weight = 0.7 * time_preference + 0.3 * timestamp_weight
# time_preference kita asumsikan 1 untuk semua preferensi.
weights = {}
for s in students:
    t_w = timestamp_weights[s]
    final_weight_pref = 0.7 * 1.0 + 0.3 * t_w  # time_pref=1.0
    # Bobot sama untuk setiap slot di (d,b) tersebut
    for (d,b) in StudentPreferences[s]["preferences"]:
        for sl in range(slot_count):
            weights[(s,d,b,sl)] = final_weight_pref

# Fungsi Objektif
model += lpSum(weights[(s,d,b,sl)] * x[(s,d,b,sl)] 
               for s in students 
               for (d,b) in StudentPreferences[s]["preferences"] 
               for sl in range(slot_count))

# Constraint 1: Setiap student dialokasikan ke paling banyak 1 slot total
for s in students:
    model += lpSum(x[(s,d,b,sl)]
                   for (d,b) in StudentPreferences[s]["preferences"]
                   for sl in range(slot_count)) <= 1

# Constraint 2: Setiap slot hanya boleh diisi oleh paling banyak 1 student
for d in days:
    for b in batches:
        for sl in range(slot_count):
            model += lpSum(x[(s,d,b,sl)]
                           for s in students
                           if (s,d,b,sl) in x) <= 1

# Solve
model.solve()

# -----------------------------------------------------
# Memetakan Solusi ke Dalam ScheduleRecommendation
# -----------------------------------------------------
# ScheduleRecommendation: array 2D [day][batch] = list studentId per slot
ScheduleRecommendation = {}
for d in days:
    d_str = str(d)
    ScheduleRecommendation[d_str] = {}
    for b in batches:
        b_str = str(b)
        ScheduleRecommendation[d_str][b_str] = [None]*slot_count

# allocated_students = set()
# for s in students:
#     for (d,b) in StudentPreferences[s]["preferences"]:
#         for sl in range(slot_count):
#             if (s,d,b,sl) in x and x[(s,d,b,sl)].varValue == 1:
#                 ScheduleRecommendation[str(d)][str(b)][sl] = s
#                 allocated_students.add(s)
#                 break
allocated_students = set()

# Dictionary untuk menyimpan indeks slot yang akan digunakan selanjutnya untuk setiap (d,b)
next_slot_index = {}
for d_str in ScheduleRecommendation.keys():
    for b_str in ScheduleRecommendation[d_str].keys():
        next_slot_index[(d_str, b_str)] = 0  # mulai dari slot 0

for s in students:
    assigned = False
    for (d,b) in StudentPreferences[s]["preferences"]:
        if assigned:
            break
        d_str, b_str = str(d), str(b)

        # Mulai pencarian slot dari next_slot_index untuk (d_str, b_str)
        start_sl = next_slot_index[(d_str, b_str)]

        # Cari slot kosong mulai dari start_sl hingga slot_count-1
        for sl in range(start_sl, slot_count):
            if ScheduleRecommendation[d_str][b_str][sl] is None:
                # Tempatkan student di slot ini
                ScheduleRecommendation[d_str][b_str][sl] = s
                allocated_students.add(s)
                assigned = True
                # Update next_slot_index ke slot berikutnya untuk alokasi berikutnya di (d_str, b_str)
                next_slot_index[(d_str, b_str)] = sl + 1
                break

    # Jika student sudah ditempatkan, tidak lanjut cari slot di preferensi berikutnya

# Setelah loop, semua student yang bisa ditempatkan telah dialokasikan slotnya

# Student yang tidak teralokasi
unallocated_students = [s for s in students if s not in allocated_students]

# -----------------------------------------------------
# Mencari slot terdekat yang masih kosong untuk unallocated students
# Sorting slot berdasarkan hari, batch, slot index
all_slots_sorted = []
for d in sorted(days):
    for b in sorted(batches):
        for sl in range(slot_count):
            start_time = AvailableSlot[d][b][sl]
            all_slots_sorted.append((d,b,sl,start_time))

empty_slots = [(d,b,sl) for (d,b,sl,start) in all_slots_sorted if ScheduleRecommendation[d][b][sl] is None]

UnAllocatedSchedule = {}
for s in unallocated_students:
    # Beri rekomendasi slot kosong pertama yang tersedia
    if empty_slots:
        suggested_slot = empty_slots.pop(0)
        UnAllocatedSchedule[s] = suggested_slot  # (day, batch, slot)
    else:
        UnAllocatedSchedule[s] = None  # Tidak ada slot kosong tersisa

# -----------------------------------------------------
# Hasil akhir:
print("ScheduleRecommendation:")
for d in sorted(ScheduleRecommendation.keys()):
    for b in sorted(ScheduleRecommendation[d].keys()):
        print(f"Day {d}, Batch {b}: {ScheduleRecommendation[d][b]}")

print("\nUnAllocatedSchedule:")
for s in UnAllocatedSchedule:
    print(f"{s}: {UnAllocatedSchedule[s]}")