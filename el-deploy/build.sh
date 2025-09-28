#!/bin/bash

# Скрипт сборки схемы электропроводки
# Собирает все модули в один файл и генерирует PNG

set -e  # Выход при ошибке

echo "🔌 Сборка схемы электропроводки..."

# Определяем директорию, где находится скрипт
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "📁 Директория скрипта: $SCRIPT_DIR"

# Создаем временный каталог если не существует
mkdir -p "$SCRIPT_DIR/tmp/electro-build"

# Проверяем существование основного файла
MAIN_D2="$SCRIPT_DIR/main.d2"
if [ ! -f "$MAIN_D2" ]; then
    echo "❌ Ошибка: main.d2 не найден в $SCRIPT_DIR"
    exit 1
fi

# Копируем основной файл
cp "$MAIN_D2" "$SCRIPT_DIR/tmp/all.d2"

# Добавляем содержимое всех модулей
echo "" >> "$SCRIPT_DIR/tmp/all.d2"
echo "# === ИМПОРТИРОВАННЫЕ МОДУЛИ ===" >> "$SCRIPT_DIR/tmp/all.d2"

# Обработка параметров командной строки
INCLUDE_FILTERS=()
FILTERS_ACTIVE=false
OUTPUT_FILE="tmp/all.png"  # Значение по умолчанию

# Парсинг аргументов командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
        --include-files)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                INCLUDE_FILTERS+=("$2")
                FILTERS_ACTIVE=true
                shift 2
            else
                echo "❌ Ошибка: --include-files требует аргумент"
                exit 1
            fi
            ;;
        --output-file)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                OUTPUT_FILE="$2"
                shift 2
            else
                echo "❌ Ошибка: --output-file требует аргумент"
                exit 1
            fi
            ;;
        *)
            # Игнорируем другие аргументы
            shift
            ;;
    esac
done

# Если указаны фильтры, выводим информацию
if [[ ${#INCLUDE_FILTERS[@]} -gt 0 ]]; then
    echo "🔍 Применены фильтры включения: ${INCLUDE_FILTERS[*]}"
fi

# Выводим информацию о выходном файле
echo "📁 Выходной файл: $OUTPUT_FILE"

# Функция для проверки Ant-style patterns
matches_ant_pattern() {
    local file="$1"
    local pattern="$2"

    # Для паттернов с **/ - проверяем совпадение в конце пути
    if [[ "$pattern" == "**/"* ]]; then
        local filename_pattern="${pattern#**/}"  # Удаляем **/ из начала

        # Проверяем, заканчивается ли путь на этот файл
        if [[ "$file" == */"$filename_pattern" ]]; then
            return 0
        fi

        # Проверяем только имя файла
        if [[ "$(basename "$file")" == "$filename_pattern" ]]; then
            return 0
        fi
    else
        # Простое сравнение полного пути или имени файла
        if [[ "$file" == "$pattern" ]] || [[ "$(basename "$file")" == "$pattern" ]]; then
            return 0
        fi
    fi

    return 1
}

# Функция проверки соответствия файла фильтрам
should_include_file() {
    local file="$1"

    # Если фильтры не активированы, включаем все файлы
    if [[ "$FILTERS_ACTIVE" == "false" ]]; then
        return 0
    fi

    # Проверяем соответствие каждому фильтру (OR логика)
    for filter in "${INCLUDE_FILTERS[@]}"; do
        if matches_ant_pattern "$file" "$filter"; then
            return 0
        fi
    done

    return 1
}

MODULES_ADDED=0

MODULES_DIR="$SCRIPT_DIR/modules"
echo "📂 Обрабатываем модули из: $MODULES_DIR"
echo "📋 Все файлы: $(echo $MODULES_DIR/*.d2)"

# ВРЕМЕННО отключаем set -e для цикла
set +e
for module in $MODULES_DIR/*.d2; do
    echo "🔄 Начало обработки: $module"
    if [ -f "$module" ]; then
        echo "🔍 Анализ модуля: $module"
        if should_include_file "$module"; then
            echo "🎯 Файл соответствует фильтрам"
            echo "" >> "$SCRIPT_DIR/tmp/all.d2"
            echo "# Модуль: $(basename $module)" >> "$SCRIPT_DIR/tmp/all.d2"
            echo "📖 Чтение содержимого..."
            cat "$module" >> "$SCRIPT_DIR/tmp/all.d2"
            CAT_EXIT_CODE=$?
            echo "📖 Код выхода cat: $CAT_EXIT_CODE"
            if [ $CAT_EXIT_CODE -eq 0 ]; then
                echo "✅ Добавлен модуль: $module"
                ((MODULES_ADDED++))
            else
                echo "❌ Ошибка при чтении $module (код: $CAT_EXIT_CODE)"
            fi
        else
            echo "⏭️  Пропущен модуль: $module (не соответствует фильтрам)"
        fi
    else
        echo "📄 $module не является файлом"
    fi
    echo "--- Конец обработки $module ---"
done
set -e  # Включаем обратно

echo "" >> "$SCRIPT_DIR/tmp/all.d2"
echo "# === КОНЕЦ СБОРКИ ===" >> "$SCRIPT_DIR/tmp/all.d2"

# Создаем директорию для выходного файла если не существует
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Генерируем PNG с ELK layout
echo "🔄 Генерация PNG с ELK layout..."
d2 --layout=elk --theme=300 "$SCRIPT_DIR/tmp/all.d2" "$OUTPUT_FILE"

# Проверяем успешность
if [ $? -eq 0 ]; then
    echo "✅ Сборка завершена успешно!"
    echo "📁 Файлы:"
    echo "   - Схема D2: $SCRIPT_DIR/tmp/all.d2"
    echo "   - Изображение: $OUTPUT_FILE"
    echo ""
    echo "📊 Статистика:"
    echo "   Размер D2 файла: $(wc -l < "$SCRIPT_DIR/tmp/all.d2") строк"
    echo "   Модулей собрано: $MODULES_ADDED"
    if [[ "$FILTERS_ACTIVE" == "true" ]]; then
        echo "   Фильтры: ${INCLUDE_FILTERS[*]}"
    fi
else
    echo "❌ Ошибка при генерации схемы"
    exit 1
fi