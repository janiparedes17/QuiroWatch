cat > /home/pi/sensor_bme280.py << 'EOF'
import smbus2
import time
import urllib.request
import json

I2C_ADDRESS = 0x76
N8N_URL = "http://10.230.111.56:5678/webhook/sensor"
INTERVALO = 30
bus = smbus2.SMBus(1)
EOF

cat >> /home/pi/sensor_bme280.py << 'EOF'
def leer_bme280():
    cal = bus.read_i2c_block_data(I2C_ADDRESS, 0x88, 24)
    dig_T1 = cal[1] << 8 | cal[0]
    dig_T2 = cal[3] << 8 | cal[2]
    if dig_T2 > 32767: dig_T2 -= 65536
    dig_T3 = cal[5] << 8 | cal[4]
    if dig_T3 > 32767: dig_T3 -= 65536
    dig_P1 = cal[7] << 8 | cal[6]
    dig_P2 = cal[9] << 8 | cal[8]
    if dig_P2 > 32767: dig_P2 -= 65536
    dig_P3 = cal[11] << 8 | cal[10]
    if dig_P3 > 32767: dig_P3 -= 65536
    dig_P4 = cal[13] << 8 | cal[12]
    if dig_P4 > 32767: dig_P4 -= 65536
    dig_P5 = cal[15] << 8 | cal[14]
    if dig_P5 > 32767: dig_P5 -= 65536
    dig_P6 = cal[17] << 8 | cal[16]
    if dig_P6 > 32767: dig_P6 -= 65536
    dig_P7 = cal[19] << 8 | cal[18]
    if dig_P7 > 32767: dig_P7 -= 65536
    dig_P8 = cal[21] << 8 | cal[20]
    if dig_P8 > 32767: dig_P8 -= 65536
    dig_P9 = cal[23] << 8 | cal[22]
    if dig_P9 > 32767: dig_P9 -= 65536
EOF

cat >> /home/pi/sensor_bme280.py << 'EOF'
    cal2 = bus.read_i2c_block_data(I2C_ADDRESS, 0xA1, 1)
    dig_H1 = cal2[0]
    cal3 = bus.read_i2c_block_data(I2C_ADDRESS, 0xE1, 7)
    dig_H2 = cal3[1] << 8 | cal3[0]
    if dig_H2 > 32767: dig_H2 -= 65536
    dig_H3 = cal3[2]
    dig_H4 = cal3[3] << 4 | (cal3[4] & 0x0F)
    if dig_H4 > 32767: dig_H4 -= 65536
    dig_H5 = cal3[5] << 4 | cal3[4] >> 4
    if dig_H5 > 32767: dig_H5 -= 65536
    dig_H6 = cal3[6]
    if dig_H6 > 127: dig_H6 -= 256
    bus.write_byte_data(I2C_ADDRESS, 0xF2, 0x01)
    bus.write_byte_data(I2C_ADDRESS, 0xF4, 0x27)
    bus.write_byte_data(I2C_ADDRESS, 0xF5, 0xA0)
    time.sleep(0.5)
    data = bus.read_i2c_block_data(I2C_ADDRESS, 0xF7, 8)
    adc_P = (data[0] << 12) | (data[1] << 4) | (data[2] >> 4)
    adc_T = (data[3] << 12) | (data[4] << 4) | (data[5] >> 4)
    adc_H = (data[6] << 8) | data[7]
EOF

cat >> /home/pi/sensor_bme280.py << 'EOF'
    var1 = ((adc_T / 16384.0) - (dig_T1 / 1024.0)) * dig_T2
    var2 = ((adc_T / 131072.0) - (dig_T1 / 8192.0)) ** 2 * dig_T3
    t_fine = var1 + var2
    temperatura = t_fine / 5120.0
    var1 = t_fine / 2.0 - 64000.0
    var2 = var1 * var1 * dig_P6 / 32768.0
    var2 = var2 + var1 * dig_P5 * 2.0
    var2 = var2 / 4.0 + dig_P4 * 65536.0
    var1 = (dig_P3 * var1 * var1 / 524288.0 + dig_P2 * var1) / 524288.0
    var1 = (1.0 + var1 / 32768.0) * dig_P1
    presion = 1048576.0 - adc_P
    presion = (presion - var2 / 4096.0) * 6250.0 / var1
    var1 = dig_P9 * presion * presion / 2147483648.0
    var2 = presion * dig_P8 / 32768.0
    presion = presion + (var1 + var2 + dig_P7) / 16.0
    presion = presion / 100.0
    humedad = t_fine - 76800.0
    humedad = (adc_H - (dig_H4 * 64.0 + dig_H5 / 16384.0 * humedad)) * (dig_H2 / 65536.0 * (1.0 + dig_H6 / 67108864.0 * humedad * (1.0 + dig_H3 / 67108864.0 * humedad)))
    humedad = humedad * (1.0 - dig_H1 * humedad / 524288.0)
    humedad = max(0.0, min(100.0, humedad))
    return round(temperatura, 2), round(humedad, 2), round(presion, 2)
EOF

cat >> /home/pi/sensor_bme280.py << 'EOF'
print("Iniciando sensor BME280...")
print(f"Enviando datos a: {N8N_URL}")
print(f"Intervalo: {INTERVALO} segundos")
print("Ctrl+C para detener\n")

while True:
    try:
        temperatura, humedad, presion = leer_bme280()
        datos = {
            "temperatura": temperatura,
            "humedad": humedad,
            "presion_externa": presion
        }
        print(f"T: {temperatura}C | H: {humedad}% | P: {presion} hPa")
        payload = json.dumps(datos).encode('utf-8')
        req = urllib.request.Request(
            N8N_URL,
            data=payload,
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                print(f"Enviado OK: {response.status}")
        except Exception as e:
            print(f"Error al enviar: {e}")
    except Exception as e:
        print(f"Error al leer sensor: {e}")
    time.sleep(INTERVALO)
EOF
