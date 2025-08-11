require 'bigdecimal'
require 'time'
require 'set'

class Ethereum::SmartContractSummaryService < Ethereum::BaseService
  attr_reader :contract_data, :address_hash
  CURRENT_DATE = Time.now

  def initialize(contract_data, address_hash)
    @contract_data = contract_data || {}
    @address_hash = address_hash
    raise ArgumentError, "address_hash cannot be nil" if address_hash.nil?
  end

  def call
    generate_text_representation(@contract_data)
  rescue => e
    puts "Error generating text for smart contract #{@address_hash}: #{e.message}"
    puts e.backtrace
    nil
  end

  private

  # Generate comprehensive text representation of smart contract data optimized for semantic search
  def generate_text_representation(data)
    data ||= {}
    
    # Start with narrative introduction
    intro = build_narrative_intro(data)
    
    # Build the flowing narrative
    narrative_parts = [intro]
    
    # Add technical story
    tech_story = build_technical_narrative(data)
    narrative_parts << tech_story if tech_story.present?
    
    # Add verification and security story
    security_story = build_security_narrative(data)
    narrative_parts << security_story if security_story.present?
    
    # Add development and ecosystem story
    ecosystem_story = build_ecosystem_narrative(data)
    narrative_parts << ecosystem_story if ecosystem_story.present?
    
    narrative_parts.join(' ')
  end

  private

  def build_narrative_intro(data)
    # Start with address hash
    intro = "Address #{@address_hash} is"
    
    # Contract type and identity
    if data['proxy_type']
      proxy_desc = "#{data['proxy_type']} proxy contract"
      if data['name'].present?
        intro += " a #{proxy_desc} named #{data['name']}"
      else
        intro += " a #{proxy_desc}"
      end
      
      # Add delegation info
      if data['implementations']&.any?
        impl_names = data['implementations'].map { |impl| impl['name'] || impl['address'] || impl['address_hash'] }
        intro += " that delegates execution to #{impl_names.join(', ')}"
      end
      
      intro += ", designed with an upgradeable architecture"
    else
      if data['name'].present?
        intro += " a direct implementation contract named #{data['name']}"
      else
        intro += " a direct implementation contract"
      end
      intro += " with an immutable design"
    end
    
    # Add blockchain context
    intro += " deployed on the Ethereum blockchain"
    
    # Add primary purpose or standard compliance
    if data['abi']&.any?
      standard_type = classify_standard_compliance(data['abi'])
      if standard_type != 'Unknown'
        intro += " following #{standard_type} standards"
      end
    end
    
    intro + "."
  end

  def build_technical_narrative(data)
    parts = []
    
    # Development story
    if data['language'] && data['compiler_version']
      compiler_info = classify_compiler_version(data['compiler_version'])
      tech_story = "The contract was developed in #{data['language']} and compiled using #{data['compiler_version']}"
      
      if compiler_info[:description]
        tech_story += ", representing #{compiler_info[:description].downcase}"
      end
      
      if data['optimization_enabled']
        opt_details = data['optimization_runs'] ? " with #{data['optimization_runs']} optimization runs" : ""
        tech_story += ". The code has been optimized for gas efficiency#{opt_details}"
      else
        tech_story += ", though it remains unoptimized for deployment size"
      end
      
      parts << tech_story + "."
    end
    
    # Code complexity and structure
    if data['source_code'].present?
      source_lines = data['source_code'].count("\n") + 1
      complexity_info = classify_complexity(source_lines)
      
      code_story = "The implementation spans #{format_number(source_lines)} lines of source code, classifying it as #{complexity_info[:tier].downcase} complexity"
      
      if data['additional_sources']&.any?
        source_count = data['additional_sources'].length
        code_story += " and is organized across #{source_count} additional source files for modular development"
      end
      
      parts << code_story + "."
    end
    
    # Interface and functionality
    if data['abi']&.any?
      function_count = data['abi'].count { |item| item['type'] == 'function' }
      event_count = data['abi'].count { |item| item['type'] == 'event' }
      
      interface_story = "The contract exposes"
      interface_parts = []
      interface_parts << "#{function_count} callable functions" if function_count > 0
      interface_parts << "#{event_count} events for logging" if event_count > 0
      
      if interface_parts.any?
        interface_story += " #{interface_parts.join(' and ')}"
        
        # Add deployment configuration
        if data['decoded_constructor_args']&.any?
          args_count = data['decoded_constructor_args'].length
          interface_story += ", and was deployed with #{args_count} constructor #{args_count == 1 ? 'parameter' : 'parameters'}"
        end
        
        parts << interface_story + "."
      end
    end
    
    # Dependencies
    if data['external_libraries']&.any?
      lib_count = data['external_libraries'].length
      dep_story = "The contract leverages #{lib_count} external #{lib_count == 1 ? 'library' : 'libraries'} for enhanced functionality"
      parts << dep_story + "."
    end
    
    parts.join(' ')
  end

  def build_security_narrative(data)
    parts = []
    risk_info = classify_risk(data)
    
    # Verification story
    if data['is_verified']
      verification_sources = []
      verification_sources << "Sourcify" if data['is_verified_via_sourcify']
      verification_sources << "ETH Bytecode Database" if data['is_verified_via_eth_bytecode_db']
      verification_sources << "Verifier Alliance" if data['is_verified_via_verifier_alliance']
      
      if verification_sources.any?
        verification_level = data['is_fully_verified'] ? "fully verified" : "verified"
        verification_story = "The contract has been #{verification_level} through #{verification_sources.join(', ')}"
        
        if data['verified_at']
          verification_story += " on #{format_timestamp(data['verified_at'])}"
        end
        
        verification_story += ", making its source code publicly auditable"
        parts << verification_story + "."
      end
    else
      parts << "The contract remains unverified, meaning its source code is not publicly available for audit."
    end
    
    # Security assessment
    security_story = "Security analysis reveals #{risk_info[:level].downcase} risk levels"
    
    if risk_info[:description] != "Fully verified with no issues"
      security_story += " due to #{risk_info[:description].downcase}"
    end
    
    # Audit status
    if data['certified']
      security_story += ". The contract has undergone professional security auditing"
    else
      security_story += ", and it has not been professionally audited"
    end
    
    # Special security considerations
    security_concerns = []
    security_concerns << "the contract has been self-destructed" if data['is_self_destructed']
    security_concerns << "the bytecode has been modified post-deployment" if data['is_changed_bytecode']
    
    if security_concerns.any?
      security_story += ". Additionally, #{security_concerns.join(' and ')}"
    end
    
    parts << security_story + "."
    
    parts.join(' ')
  end

  def build_ecosystem_narrative(data)
    parts = []
    features = []
    
    # License and legal framework
    if data['license_type'].present? && data['license_type'] != 'none'
      license_info = classify_license(data['license_type'])
      features << "operates under a #{license_info[:tier].downcase} license framework"
    else
      features << "has no specified license"
    end
    
    # Development tools and ecosystem
    dev_features = []
    dev_features << "supports UML diagram visualization" if data['can_be_visualized_via_sol2uml']
    dev_features << "is integrated with Sourcify for decentralized verification" if data['sourcify_repo_url']
    dev_features << "has a verified twin contract available" if data['verified_twin_address_hash']
    dev_features << "serves as a blueprint for other implementations" if data['is_blueprint']
    
    if dev_features.any?
      features << "#{dev_features.join(', ')}"
    end
    
    # EVM compatibility
    if data['evm_version'] && data['evm_version'] != 'default'
      features << "targets EVM #{data['evm_version']} specification"
    end
    
    # Contract maturity
    if data['verified_at']
      verified_time = Time.parse(data['verified_at'])
      age_days = ((CURRENT_DATE - verified_time) / (3600 * 24)).to_i
      age_info = classify_age(age_days)
      features << "has #{age_info[:tier].downcase} maturity (#{age_info[:description].downcase})"
    end
    
    if features.any?
      ecosystem_story = "From an ecosystem perspective, the contract #{features.join(', ')}"
      parts << ecosystem_story + "."
    end
    
    parts.join(' ')
  end

  # Helper to format timestamp
  def format_timestamp(timestamp_str)
    return "unknown time" unless timestamp_str
    Time.parse(timestamp_str).strftime("%B %d, %Y at %H:%M:%S UTC")
  rescue
    timestamp_str
  end

  # Helper to format large numbers with commas
  def format_number(number)
    return "0" unless number
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  # New: Classify contract age based on verified_at
  def classify_age(age_days)
    case age_days
    when 0...365
      { tier: 'New', description: '<1 year old' }
    when 365...1095
      { tier: 'Mature', description: '1-3 years old' }
    else
      { tier: 'Legacy', description: '>3 years old' }
    end
  end

  # New: Classify upgradability
  def classify_upgradability(data)
    if data['proxy_type']
      { level: 'Upgradable', description: "Via #{data['proxy_type']} proxy pattern" }
    else
      { level: 'Immutable', description: 'No proxy detected' }
    end
  end

  # New: Classify compiler version (e.g., legacy vs. modern)
  def classify_compiler_version(version)
    return {} unless version
    major, minor = version.match(/v(\d+)\.(\d+)/)&.captures&.map(&:to_i) || [0, 0]
    if major == 0 && minor < 5
      { tier: 'Legacy', description: 'Pre-0.5 Solidity version' }
    elsif major == 0 && minor < 8
      { tier: 'Standard', description: '0.5-0.7 Solidity version' }
    else
      { tier: 'Modern', description: '0.8+ Solidity version' }
    end
  end

  # New: Classify complexity based on source lines
  def classify_complexity(source_lines)
    case source_lines
    when 0...100
      { tier: 'Low', description: 'Simple contract (<100 lines)' }
    when 100...500
      { tier: 'Medium', description: 'Moderately complex (100-500 lines)' }
    else
      { tier: 'High', description: 'Complex contract (>500 lines)' }
    end
  end

  # New: Classify standard compliance (e.g., ERC-20, Proxy)
  def classify_standard_compliance(abi)
    return 'Unknown' unless abi
    has_erc20 = abi.any? { |item| item['type'] == 'function' && %w[transfer approve balanceOf totalSupply allowance].include?(item['name']) } &&
                abi.any? { |item| item['type'] == 'event' && %w[Transfer Approval].include?(item['name']) }
    has_proxy = abi.any? { |item| item['type'] == 'function' && %w[upgradeTo changeAdmin implementation admin].include?(item['name']) }
    if has_erc20
      'ERC-20 Token'
    elsif has_proxy
      'Proxy Contract'
    else
      'Custom Contract'
    end
  end

  # New: Classify security/risk level
  def classify_risk(data)
    risk_factors = []
    risk_factors << "self-destructed" if data['is_self_destructed']
    risk_factors << "has changed bytecode" if data['is_changed_bytecode']
    risk_factors << "not verified" unless data['is_verified']
    risk_factors << "partially verified" if data['is_partially_verified'] && !data['is_fully_verified']

    if risk_factors.any?
      level = risk_factors.length > 1 ? 'High' : 'Medium'
      { level: level, description: risk_factors.join(', ') }
    else
      { level: 'Low', description: 'Fully verified with no issues' }
    end
  end

  # New: Classify license type
  def classify_license(license_type)
    case license_type&.downcase
    when /mit|apache|bsd/
      { tier: 'Permissive Open Source', description: 'Allows broad use and modification' }
    when /gpl|agpl/
      { tier: 'Copyleft Open Source', description: 'Requires sharing modifications' }
    when 'none'
      { tier: 'Proprietary', description: 'No license specified' }
    else
      { tier: 'Custom', description: 'Other license type' }
    end
  end
end