require 'httparty'
require 'csv'
require 'json'
require 'tk'

# Валідація назви міста
def valid_city_name?(city)
  city.match?(/\A[a-zA-Z\s\-]+\z/)
end

# Отримання даних про погоду
def fetch_weather_data(city, api_key)
  unless valid_city_name?(city)
    Tk.messageBox(
      type: 'ok',
      icon: 'error',
      title: 'Error',
      message: 'The name of the city must contain only Latin letters!'
    )
    return nil
  end

  begin
    url = "http://api.openweathermap.org/data/2.5/weather?q=#{city}&appid=#{api_key}&units=metric"
    response = HTTParty.get(url, timeout: 10)

    if response.code == 200
      weather_data = response.parsed_response
      {
        city: weather_data['name'],
        country: weather_data['sys']['country'],
        temperature: weather_data['main']['temp'],
        temperature_fells: weather_data['main']['feels_like'],
        humidity: weather_data['main']['humidity'],
        wind_speed: weather_data['wind']['speed'],
        wind_direction: weather_data['wind']['deg'],
        pressure: weather_data['main']['pressure'],
        weather_description: weather_data['weather'][0]['description']
      }
    else
      Tk.messageBox(
        type: 'ok',
        icon: 'error',
        title: 'Error',
        message: 'Failed to get weather data. Check API key and city name.'
      )
      nil
    end
  rescue StandardError => e
    Tk.messageBox(
      type: 'ok',
      icon: 'error',
      title: 'Error',
      message: "An error occurred: #{e.message}"
    )
    nil
  end
end

# Збереження даних у CSV
def save_to_csv(data, file_name, append: false)
  return if data.nil? || data.empty? || file_name.nil? || file_name.empty?

  mode = append ? 'a' : 'w'
  CSV.open(file_name, mode, headers: true) do |csv|
    if mode == 'w'
      csv << ['City', 'Country', 'Temperature (C)', 'Feels Like (C)', 'Humidity (%)',
              'Wind Speed (m/s)', 'Wind Direction (°)', 'Pressure (hPa)', 'Weather Description']
    end
    data.each do |record|
      csv << [
        record[:city],
        record[:country],
        record[:temperature],
        record[:temperature_fells],
        record[:humidity],
        record[:wind_speed],
        record[:wind_direction],
        record[:pressure],
        record[:weather_description]
      ]
    end
  end
end

# Збереження даних у JSON
def save_to_json(data, file_name, append: false)
  return if data.nil? || data.empty? || file_name.nil? || file_name.empty?

  existing_data = []

  if append && File.exist?(file_name)
    existing_data = JSON.parse(File.read(file_name), symbolize_names: true)
  end

  File.open(file_name, 'w') do |file|
    file.write(JSON.pretty_generate(existing_data + data))
  end
end

# Функція створення контекстного меню
def add_context_menu(entry)
  menu = TkMenu.new(entry)
  menu.add('command', label: 'Copy', command: proc { TkClipboard.append(entry.selection_get) })
  menu.add('command', label: 'Paste', command: proc { entry.insert('insert', TkClipboard.get) })
  entry.bind('Button-3') { |event| menu.popup(event.x_root, event.y_root) }
end

# Створення UI
root = TkRoot.new { title 'Weather App' }

# Логотип
logo = TkPhotoImage.new(file: 'img/logo.png') # Файл логотипа до каталогу
TkLabel.new(root) {
  image logo
  pack
}

# Поле для API-ключа
TkLabel.new(root) { text 'API Key:'; pack }
api_key_var = TkVariable.new
api_key_entry = TkEntry.new(root) { textvariable api_key_var; show '*'; pack }
add_context_menu(api_key_entry)
TkCheckButton.new(root) {
  text 'Show API Key'
  variable TkVariable.new
  command { api_key_entry.show(api_key_entry.show == '*' ? '' : '*') }
  pack
}

# Поле для міста
TkLabel.new(root) { text 'City:'; pack }
city_var = TkVariable.new
city_entry = TkEntry.new(root) { textvariable city_var; pack }
add_context_menu(city_entry)

# Кнопка отримання погоди
TkButton.new(root) {
  text 'Find city weather'
  command {
    city = city_var.value
    key = api_key_var.value
    weather_data = fetch_weather_data(city, key)
    if weather_data
      Tk.messageBox(
        type: 'ok',
        icon: 'info',
        title: 'Weather',
        message: "City: #{weather_data[:city]}\n
        Country: #{weather_data[:country]}\n
        Temperature (C): #{weather_data[:temperature]}°C\n
        Feels Like (C): #{weather_data[:temperature_fells]} C\n
        Humidity (%): #{weather_data[:humidity]} %\n
        Wind Speed (m/s): #{weather_data[:wind_speed]} m/s\n
        Wind Direction (°): #{weather_data[:wind_direction]} (°)\n
        Pressure (hPa): #{weather_data[:pressure]} hPa\n
        Weather conditions in general: #{weather_data[:weather_description]}"
      )
    end
  }
  background '#008080'
  foreground 'white'
  pack(pady: 10)
}

button_frame = TkFrame.new(root) { pack(side: 'top', pady: 10) }

# Кнопка збереження даних у CSV
TkButton.new(button_frame) {
  text 'Save to CSV'
  command {
    append = Tk.messageBox(
      type: 'yesno',
      icon: 'question',
      title: 'Preservation',
      message: 'Add to an existing file?'
    ) == 'yes'

    file_name = if append
                  Tk.getOpenFile(
                    title: 'Select an existing file to append data',
                    filetypes: [['CSV Files', '*.csv']]
                  )
                else
                  Tk.getSaveFile(
                    title: 'Save as new file',
                    filetypes: [['CSV Files', '*.csv']],
                    defaultextension: '.csv'
                  )
                end

    if file_name && !file_name.empty?
      city = city_var.value
      key = api_key_var.value
      weather_data = fetch_weather_data(city, key)
      save_to_csv([weather_data], file_name, append: append) if weather_data
    else
      Tk.messageBox(
        type: 'ok',
        icon: 'warning',
        title: 'Error',
        message: 'File was not selected!'
      )
    end
  }
  background '#4682b4'
  foreground 'white'
  pack(side: 'left', padx: 5)
}

# Кнопка збереження даних у JSON
TkButton.new(button_frame) {
  text 'Save to JSON'
  command {
    append = Tk.messageBox(
      type: 'yesno',
      icon: 'question',
      title: 'Preservation',
      message: 'Add to an existing file?'
    ) == 'yes'

    file_name = if append
                  Tk.getOpenFile(
                    title: 'Select an existing file to append data',
                    filetypes: [['JSON Files', '*.json']]
                  )
                else
                  Tk.getSaveFile(
                    title: 'Save as new file',
                    filetypes: [['JSON Files', '*.json']],
                    defaultextension: '.json'
                  )
                end

    if file_name && !file_name.empty?
      city = city_var.value
      key = api_key_var.value
      weather_data = fetch_weather_data(city, key)
      save_to_json([weather_data], file_name, append: append) if weather_data
    else
      Tk.messageBox(
        type: 'ok',
        icon: 'warning',
        title: 'Error',
        message: 'File was not selected!'
      )
    end
  }
  background '#4682b4'
  foreground 'white'
  pack(side: 'left', padx: 5)
}

# Кнопка виходу
TkButton.new(root) {
  text 'Exit'
  command { exit }
  background '#b22222'
  foreground 'white'
  pack
}

Tk.mainloop