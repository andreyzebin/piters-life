#!/bin/bash

# Скрипт сборки схемы электропроводки
# Собирает все модули в один файл и генерирует PNG

set -e  # Выход при ошибке

echo "🔌 Сборка схемы электропроводки..."

# Создаем временный каталог если не существует
mkdir -p tmp/electro-build

# Копируем основной файл
cp main.d2 tmp/all.d2

# Добавляем содержимое всех модулей
echo "" >> tmp/all.d2
echo "# === ИМПОРТИРОВАННЫЕ МОДУЛИ ===" >> tmp/all.d2

for module in modules/*.d2; do
    if [ -f "$module" ]; then
        echo "" >> tmp/all.d2
        echo "# Модуль: $(basename $module)" >> tmp/all.d2
        cat "$module" >> tmp/all.d2
        echo "✅ Добавлен модуль: $module"
    fi
done

echo "" >> tmp/all.d2
echo "# === КОНЕЦ СБОРКИ ===" >> tmp/all.d2

# Генерируем PNG с ELK layout
echo "🔄 Генерация PNG с ELK layout..."
d2 --layout=elk --theme=300 tmp/all.d2 tmp/all.png

# Проверяем успешность
if [ $? -eq 0 ]; then
    echo "✅ Сборка завершена успешно!"
    echo "📁 Файлы:"
    echo "   - Схема D2: tmp/all.d2"
    echo "   - Изображение: tmp/all.png"
    echo ""
    echo "📊 Статистика:"
    echo "   Размер D2 файла: $(wc -l < tmp/all.d2) строк"
    echo "   Модулей собрано: $(ls modules/*.d2 | wc -l)"
else
    echo "❌ Ошибка при генерации схемы"
    exit 1
fi