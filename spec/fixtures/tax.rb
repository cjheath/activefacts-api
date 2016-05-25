require 'activefacts/api'

module Tax

  class Name < String
    value_type
  end

  class Person
    identified_by :name
    one_to_one :name
  end

  class Australian < Person
  end

  class TaxPayer < Person
  end

  class TFN < Int
    value_type
  end

  class AustralianTaxPayer < Australian
    supertypes TaxPayer
    identified_by :tfn
    one_to_one :tfn, :class => TFN  # Capitalisation rules!
  end

  class YearNr < Int
    value_type
  end

  class Year
    identified_by :year_nr
    one_to_one :year_nr
  end

  class AustralianTaxReturn
    identified_by :australian_tax_payer, :year
    has_one :australian_tax_payer
    has_one :year
    has_one :reviewer, class: Person
  end

end
