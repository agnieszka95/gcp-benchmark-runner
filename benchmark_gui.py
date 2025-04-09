import tkinter as tk
from tkinter import messagebox
import subprocess

def run_vm_creation():
    instance = instance_name.get()
    machine = machine_type.get()
    cores = cpu_cores.get()
    memory = ram.get()

    cmd = f"./setupvm/setup_vm.sh {instance} {machine} {cores} {memory}"
    try:
        output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
        log_box.insert(tk.END, output.decode())
    except subprocess.CalledProcessError as e:
        log_box.insert(tk.END, e.output.decode())

def run_benchmark():
    try:
        output = subprocess.check_output("bash scripts/benchmark_execution.sh", shell=True, stderr=subprocess.STDOUT)
        log_box.insert(tk.END, output.decode())
    except subprocess.CalledProcessError as e:
        log_box.insert(tk.END, e.output.decode())

# GUI setup
root = tk.Tk()
root.title("Plonky2 Benchmark Launcher")

tk.Label(root, text="Instance Name").pack()
instance_name = tk.Entry(root)
instance_name.pack()

tk.Label(root, text="Machine Type").pack()
machine_type = tk.Entry(root)
machine_type.insert(0, "custom")
machine_type.pack()

tk.Label(root, text="CPU Cores").pack()
cpu_cores = tk.Entry(root)
cpu_cores.insert(0, "2")
cpu_cores.pack()

tk.Label(root, text="RAM (e.g., 8GB)").pack()
ram = tk.Entry(root)
ram.insert(0, "8GB")
ram.pack()

tk.Button(root, text="Launch VM", command=run_vm_creation).pack(pady=5)
tk.Button(root, text="Run Benchmark", command=run_benchmark).pack(pady=5)

log_box = tk.Text(root, height=15, width=80)
log_box.pack()

root.mainloop()
