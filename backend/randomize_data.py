import random
import datetime

# Parameter
num_students = 20
days = [1, 2]
batches = [1, 2]

all_possible_prefs = [(d, b) for d in days for b in batches]  # [(1,1),(1,2),(2,1),(2,2)]

# Fungsi untuk membuat timestamp acak
def random_timestamp(base_time, max_hours=4):
    # max_hours = 4 artinya timestamp bisa berbeda sampai 4 jam dari base_time
    # Kita random offset dalam hitungan menit
    delta_minutes = random.randint(0, max_hours * 60)
    return (base_time + datetime.timedelta(minutes=delta_minutes)).isoformat()

base_time = datetime.datetime(2024, 12, 10, 8, 0, 0)  # start: 2024-12-10 08:00:00

StudentPreferences = {}
for i in range(1, num_students+1):
    student_id = f"student{i}"
    # Pilih jumlah preferensi antara 2 sampai 4
    pref_count = random.randint(2, 4)
    chosen_prefs = random.sample(all_possible_prefs, pref_count)

    # Buat timestamp acak
    timestamp_str = random_timestamp(base_time, max_hours=4)

    StudentPreferences[student_id] = {
        "timestamp": timestamp_str,
        "preferences": chosen_prefs
    }

#create json file
import json
with open('backend/preferences.json', 'w') as f:
    json.dump(StudentPreferences, f)    

# Cetak hasil
for s in StudentPreferences:
    #save to json
    print(s, StudentPreferences[s])